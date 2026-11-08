package bo.ciomed.medozone.facturacion;

import bo.ciomed.medozone.common.EmailService;
import bo.ciomed.medozone.common.SmsService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/facturas")
@PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA')")
public class FacturaController {
    private final JdbcTemplate jdbc;
    private final SmsService smsService;
    private final EmailService emailService;

    public FacturaController(JdbcTemplate jdbc, SmsService smsService, EmailService emailService) {
        this.jdbc = jdbc;
        this.smsService = smsService;
        this.emailService = emailService;
    }

    @GetMapping
    public List<FacturaDto> listar() {
        return jdbc.query(
            "SELECT f.id, f.paciente_id, p.nombres || ' ' || p.apellidos AS paciente, " +
            "p.documento, p.telefono, p.email, " +
            "f.concepto, f.total, f.estado, f.emitida_en, " +
            "COALESCE((SELECT SUM(monto) FROM pago WHERE factura_id = f.id), 0) AS pagado " +
            "FROM factura f JOIN paciente p ON p.id = f.paciente_id " +
            "ORDER BY f.emitida_en DESC",
            (rs, rn) -> {
                BigDecimal total = rs.getBigDecimal("total");
                BigDecimal pagado = rs.getBigDecimal("pagado");
                BigDecimal saldo = total.subtract(pagado);
                return new FacturaDto(
                    rs.getLong("id"), rs.getLong("paciente_id"), rs.getString("paciente"),
                    rs.getString("documento"), rs.getString("telefono"), rs.getString("email"),
                    rs.getString("concepto"), total, pagado, saldo, rs.getString("estado"),
                    rs.getTimestamp("emitida_en").toLocalDateTime()
                );
            }
        );
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public void crear(@Valid @RequestBody FacturaRequest request, Authentication auth) {
        jdbc.update(
            "INSERT INTO factura(paciente_id, concepto, total, estado, creado_por) VALUES (?, ?, ?, 'PENDIENTE', ?)",
            request.pacienteId(), request.concepto().trim(), request.total(), auth.getName()
        );
    }

    @GetMapping("/{id}/pagos")
    public List<PagoDto> listarPagos(@PathVariable long id) {
        return jdbc.query(
            "SELECT id, monto, metodo, registrado_por, pagado_en FROM pago WHERE factura_id = ? ORDER BY pagado_en DESC",
            (rs, rn) -> new PagoDto(
                rs.getLong("id"), rs.getBigDecimal("monto"), rs.getString("metodo"),
                rs.getString("registrado_por"), rs.getTimestamp("pagado_en").toLocalDateTime()
            ), id
        );
    }

    @PostMapping("/{id}/pagos")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public void registrarPago(@PathVariable long id, @Valid @RequestBody PagoRequest request, Authentication auth) {
        List<String> factura = jdbc.queryForList("SELECT estado FROM factura WHERE id=?", String.class, id);
        if (factura.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Factura no encontrada.");
        if ("PAGADA".equals(factura.getFirst())) throw new ResponseStatusException(HttpStatus.CONFLICT, "Esta factura ya está pagada.");

        jdbc.update(
            "INSERT INTO pago(factura_id, monto, metodo, registrado_por) VALUES (?, ?, ?, ?)",
            id, request.monto(), request.metodo().toUpperCase(), auth.getName()
        );

        BigDecimal totalFactura = jdbc.queryForObject("SELECT total FROM factura WHERE id=?", BigDecimal.class, id);
        BigDecimal totalPagado = jdbc.queryForObject("SELECT COALESCE(SUM(monto), 0) FROM pago WHERE factura_id=?", BigDecimal.class, id);

        if (totalPagado != null && totalPagado.compareTo(totalFactura) >= 0) {
            jdbc.update("UPDATE factura SET estado='PAGADA' WHERE id=?", id);
        }
    }

    @PostMapping("/{id}/whatsapp")
    @ResponseStatus(HttpStatus.OK)
    public void enviarWhatsApp(@PathVariable long id) {
        FacturaDto factura = listar().stream().filter(f -> f.id() == id).findFirst()
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Factura no encontrada."));

        smsService.enviarFacturaWhatsApp(
            factura.telefono(), factura.paciente(), factura.concepto(),
            factura.total().toString(), factura.pagado().toString(), factura.saldo().toString()
        );
    }

    @PostMapping("/{id}/email")
    @ResponseStatus(HttpStatus.OK)
    public void enviarCorreo(@PathVariable long id, @RequestBody EmailRequest request) {
        FacturaDto factura = listar().stream().filter(f -> f.id() == id).findFirst()
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Factura no encontrada."));

        if (factura.email() == null || factura.email().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El paciente no tiene correo electrónico registrado.");
        }

        emailService.enviarFacturaPdf(factura.email(), factura.paciente(), String.valueOf(factura.id()), request.pdfBase64());
    }

    public record FacturaRequest(@NotNull Long pacienteId, @NotBlank String concepto, @NotNull @Positive BigDecimal total) {}
    public record PagoRequest(@NotNull @Positive BigDecimal monto, @NotBlank String metodo) {}
    public record EmailRequest(@NotBlank String pdfBase64) {}

    public record FacturaDto(
        long id, long pacienteId, String paciente, String documento,
        String telefono, String email, String concepto,
        BigDecimal total, BigDecimal pagado, BigDecimal saldo,
        String estado, LocalDateTime emitidaEn
    ) {}
    public record PagoDto(long id, BigDecimal monto, String metodo, String registradoPor, LocalDateTime fecha) {}
}