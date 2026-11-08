package bo.ciomed.medozone.pacientes;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.sql.Date;
import java.util.List;

@RestController
@RequestMapping("/api/pacientes")
@PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA','MEDICO','ENFERMERA')")
public class PacienteController {
    private final JdbcTemplate jdbc;

    public PacienteController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<PacienteDto> listar() {
        return jdbc.query(
                "SELECT id, nombres, apellidos, documento, telefono, email, fecha_nacimiento, observaciones, activo, estado_clinico " +
                "FROM paciente WHERE activo = TRUE ORDER BY apellidos, nombres",
                (rs, rowNum) -> new PacienteDto(
                        rs.getLong("id"), rs.getString("nombres"), rs.getString("apellidos"),
                        rs.getString("documento"), rs.getString("telefono"), rs.getString("email"),
                        rs.getDate("fecha_nacimiento") != null ? rs.getDate("fecha_nacimiento").toString() : null,
                        rs.getString("observaciones"), rs.getBoolean("activo"), rs.getString("estado_clinico")
                )
        );
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA')")
    @Transactional
    public PacienteDto crear(@Valid @RequestBody PacienteRequest request) {
        Long id = jdbc.queryForObject(
                "INSERT INTO paciente(nombres, apellidos, documento, telefono, email, fecha_nacimiento, observaciones, estado_clinico) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, 'NUEVO') RETURNING id",
                Long.class, request.nombres().trim(), request.apellidos().trim(),
                vacioANulo(request.documento()), vacioANulo(request.telefono()),
                vacioANulo(request.email()), parseDate(request.fechaNacimiento()),
                vacioANulo(request.observaciones())
        );
        return buscarPorId(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA','MEDICO','ENFERMERA')")
    @Transactional
    public PacienteDto actualizar(@PathVariable long id, @Valid @RequestBody PacienteRequest request) {
        int modificadas = jdbc.update(
                "UPDATE paciente SET nombres=?, apellidos=?, documento=?, telefono=?, email=?, fecha_nacimiento=?, observaciones=? WHERE id=? AND activo=TRUE",
                request.nombres().trim(), request.apellidos().trim(),
                vacioANulo(request.documento()), vacioANulo(request.telefono()),
                vacioANulo(request.email()), parseDate(request.fechaNacimiento()),
                vacioANulo(request.observaciones()), id
        );
        if (modificadas == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Paciente no encontrado.");
        }
        return buscarPorId(id);
    }

    @PatchMapping("/{id}/alta")
    @PreAuthorize("hasAnyRole('ADMIN','MEDICO')")
    @Transactional
    public void darDeAlta(@PathVariable long id) {
        jdbc.update("UPDATE paciente SET estado_clinico='ALTA' WHERE id=?", id);
    }

    private PacienteDto buscarPorId(long id) {
        return jdbc.query(
                "SELECT id, nombres, apellidos, documento, telefono, email, fecha_nacimiento, observaciones, activo, estado_clinico FROM paciente WHERE id=?",
                (rs, rowNum) -> new PacienteDto(
                        rs.getLong("id"), rs.getString("nombres"), rs.getString("apellidos"),
                        rs.getString("documento"), rs.getString("telefono"), rs.getString("email"),
                        rs.getDate("fecha_nacimiento") != null ? rs.getDate("fecha_nacimiento").toString() : null,
                        rs.getString("observaciones"), rs.getBoolean("activo"), rs.getString("estado_clinico")
                ), id
        ).stream().findFirst().orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Paciente no encontrado."));
    }

    private String vacioANulo(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }

    private Date parseDate(String fecha) {
        if (fecha == null || fecha.isBlank()) return null;
        try {
            return Date.valueOf(fecha);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    public record PacienteRequest(
            @NotBlank String nombres, @NotBlank String apellidos, String documento,
            String telefono, String email, String fechaNacimiento, String observaciones, String estadoClinico
    ) {}

    public record PacienteDto(
            long id, String nombres, String apellidos, String documento,
            String telefono, String email, String fechaNacimiento, String observaciones, boolean activo, String estadoClinico
    ) {}
}