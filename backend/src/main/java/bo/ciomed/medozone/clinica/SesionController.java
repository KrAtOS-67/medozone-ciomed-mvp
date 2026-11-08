package bo.ciomed.medozone.clinica;

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
@RequestMapping("/api/sesiones")
@PreAuthorize("hasAnyRole('ADMIN','MEDICO','ENFERMERA')")
public class SesionController {
    private final JdbcTemplate jdbc;

    public SesionController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @PostMapping("/preparar")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','ENFERMERA')")
    @Transactional
    public void prepararSesion(@Valid @RequestBody PrepararRequest request, Authentication auth) {
        Integer existe = jdbc.queryForObject("SELECT COUNT(*) FROM sesion_tratamiento WHERE cita_id=?", Integer.class, request.citaId());
        if (existe != null && existe > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Esta cita ya tiene una sesión en curso.");
        }
        jdbc.update(
            "INSERT INTO sesion_tratamiento(cita_id, dosis, presion, temperatura, frecuencia_cardiaca, " +
            "frecuencia_respiratoria, saturacion_oxigeno, peso, talla, duracion_minutos, observaciones, registrado_por, estado) " +
            "VALUES (?, 0, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, 'PENDIENTE')",
            request.citaId(), request.presion(), request.temperatura(), request.frecuenciaCardiaca(),
            request.frecuenciaRespiratoria(), request.saturacionOxigeno(), request.peso(), request.talla(),
            request.observaciones(), auth.getName()
        );
    }

    @PatchMapping("/{id}/completar")
    @PreAuthorize("hasAnyRole('ADMIN','MEDICO')")
    @Transactional
    public void completarSesion(@PathVariable long id, @Valid @RequestBody CompletarRequest request, Authentication auth) {
        List<String> sesion = jdbc.queryForList("SELECT estado FROM sesion_tratamiento WHERE id=?", String.class, id);
        if (sesion.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Sesión no encontrada.");
        if ("COMPLETADA".equals(sesion.getFirst())) throw new ResponseStatusException(HttpStatus.CONFLICT, "Esta sesión ya fue completada.");

        jdbc.update(
            "UPDATE sesion_tratamiento SET dosis=?, duracion_minutos=?, observaciones=CONCAT(observaciones, ' | Medico: ', ?), estado='COMPLETADA', registrado_por=? WHERE id=?",
            request.dosis(), request.duracionMinutos(), request.observaciones(), auth.getName(), id
        );
        Long citaId = jdbc.queryForObject("SELECT cita_id FROM sesion_tratamiento WHERE id=?", Long.class, id);
        jdbc.update("UPDATE cita SET estado='ATENDIDA' WHERE id=?", citaId);
    }

    @GetMapping
    public List<SesionListDto> listar() {
        return jdbc.query(
            "SELECT s.id, p.nombres || ' ' || p.apellidos AS paciente, c.tipo_tratamiento, " +
            "s.registrado_en, s.dosis, s.presion, s.temperatura, s.frecuencia_cardiaca, s.frecuencia_respiratoria, " +
            "s.saturacion_oxigeno, s.peso, s.talla, s.duracion_minutos, s.observaciones, s.registrado_por, s.estado " +
            "FROM sesion_tratamiento s JOIN cita c ON c.id = s.cita_id JOIN paciente p ON p.id = c.paciente_id " +
            "ORDER BY s.registrado_en DESC",
            (rs, rn) -> mapDto(rs)
        );
    }

    @GetMapping("/paciente/{pacienteId}")
    public List<SesionListDto> historial(@PathVariable long pacienteId) {
        return jdbc.query(
            "SELECT s.id, p.nombres || ' ' || p.apellidos AS paciente, c.tipo_tratamiento, " +
            "s.registrado_en, s.dosis, s.presion, s.temperatura, s.frecuencia_cardiaca, s.frecuencia_respiratoria, " +
            "s.saturacion_oxigeno, s.peso, s.talla, s.duracion_minutos, s.observaciones, s.registrado_por, s.estado " +
            "FROM sesion_tratamiento s JOIN cita c ON c.id = s.cita_id JOIN paciente p ON p.id = c.paciente_id " +
            "WHERE c.paciente_id = ? ORDER BY s.registrado_en DESC",
            (rs, rn) -> mapDto(rs), pacienteId
        );
    }

    private SesionListDto mapDto(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new SesionListDto(
            rs.getLong("id"), rs.getString("paciente"), rs.getString("tipo_tratamiento"),
            rs.getTimestamp("registrado_en").toLocalDateTime(), rs.getBigDecimal("dosis"),
            rs.getString("presion"), rs.getBigDecimal("temperatura"), rs.getObject("frecuencia_cardiaca", Integer.class),
            rs.getObject("frecuencia_respiratoria", Integer.class), rs.getObject("saturacion_oxigeno", Integer.class),
            rs.getBigDecimal("peso"), rs.getBigDecimal("talla"), rs.getInt("duracion_minutos"),
            rs.getString("observaciones"), rs.getString("registrado_por"), rs.getString("estado")
        );
    }

    public record PrepararRequest(@NotNull Long citaId, String presion, BigDecimal temperatura, Integer frecuenciaCardiaca,
                                  Integer frecuenciaRespiratoria, Integer saturacionOxigeno, BigDecimal peso, BigDecimal talla,
                                  String observaciones) {}
    public record CompletarRequest(@NotNull @Min(0) BigDecimal dosis, @NotNull @Min(1) @Max(240) int duracionMinutos, String observaciones) {}
    public record SesionListDto(long id, String paciente, String tipoTratamiento, LocalDateTime fecha, BigDecimal dosis,
                                String presion, BigDecimal temperatura, Integer fc, Integer fr, Integer spo2,
                                BigDecimal peso, BigDecimal talla, int duracionMinutos, String observaciones,
                                String registradoPor, String estado) {}
}