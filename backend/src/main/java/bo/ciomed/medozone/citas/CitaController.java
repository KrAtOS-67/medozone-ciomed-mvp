package bo.ciomed.medozone.citas;

import bo.ciomed.medozone.pacientes.PacienteService;
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
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/api/citas")
@PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA','MEDICO','ENFERMERA')")
public class CitaController {
    private final JdbcTemplate jdbc;
    private final PacienteService pacienteService;
    private static final Set<String> ESTADOS_VALIDOS = Set.of("PROGRAMADA", "CONFIRMADA", "ATENDIDA", "CANCELADA", "AUSENTE");

    public CitaController(JdbcTemplate jdbc, PacienteService pacienteService) {
        this.jdbc = jdbc;
        this.pacienteService = pacienteService;
    }

    @GetMapping("/disponibilidad")
    public List<SlotDto> disponibilidad(
            @RequestParam @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fecha,
            @RequestParam(required = false) String profesional,
            @RequestParam(required = false) String recurso,
            @RequestParam(defaultValue = "60") int duracionMinutos,
            @RequestParam(required = false) Long excludeCitaId) {
        LocalTime apertura = LocalTime.of(7, 0);
        LocalTime cierre = LocalTime.of(20, 0);
        LocalDateTime ahora = LocalDateTime.now(ZoneId.of("America/La_Paz"));
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("HH:mm");
        List<SlotDto> slots = new ArrayList<>();
        LocalTime cursor = apertura;
        while (!cursor.plusMinutes(duracionMinutos).isAfter(cierre)) {
            LocalDateTime inicio = LocalDateTime.of(fecha, cursor);
            LocalDateTime fin = inicio.plusMinutes(duracionMinutos);
            boolean esPasado = fecha.isEqual(ahora.toLocalDate()) && !inicio.isAfter(ahora);
            boolean ocupado = !esPasado && hayCruce(inicio, fin, profesional, recurso, excludeCitaId);
            slots.add(new SlotDto(cursor.format(fmt), !esPasado && !ocupado));
            cursor = cursor.plusMinutes(duracionMinutos);
        }
        return slots;
    }

    private boolean hayCruce(LocalDateTime inicio, LocalDateTime fin, String profesional, String recurso, Long excludeCitaId) {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM cita WHERE estado NOT IN ('CANCELADA', 'AUSENTE') AND inicio < ? AND inicio + (duracion_minutos * INTERVAL '1 minute') > ? AND (");
        List<Object> params = new ArrayList<>();
        params.add(Timestamp.valueOf(fin));
        params.add(Timestamp.valueOf(inicio));
        boolean hayCondicion = false;
        if (profesional != null && !profesional.isBlank()) {
            sql.append("lower(profesional) = lower(?)");
            params.add(profesional.trim());
            hayCondicion = true;
        }
        if (recurso != null && !recurso.isBlank()) {
            if (hayCondicion) sql.append(" OR ");
            sql.append("lower(recurso) = lower(?)");
            params.add(recurso.trim());
        }
        sql.append(")");
        if (excludeCitaId != null) {
            sql.append(" AND id <> ?");
            params.add(excludeCitaId);
        }
        Integer count = jdbc.queryForObject(sql.toString(), Integer.class, params.toArray());
        return count != null && count > 0;
    }

    @GetMapping("/historial")
    public List<CitaDto> historial(@RequestParam(required = false) String paciente, Authentication auth) {
        boolean esMedico = auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_MEDICO"));
        StringBuilder sql = new StringBuilder(
            "SELECT c.id, c.paciente_id, p.nombres || ' ' || p.apellidos AS paciente, p.documento, " +
            "c.profesional, c.recurso, c.tipo_tratamiento, c.inicio, c.duracion_minutos, c.estado, " +
            "s.id AS sesion_id, s.estado AS sesion_estado, s.presion, s.temperatura, s.frecuencia_cardiaca AS fc, " +
            "s.frecuencia_respiratoria AS fr, s.saturacion_oxigeno AS spo2, s.peso, s.talla " +
            "FROM cita c JOIN paciente p ON p.id = c.paciente_id " +
            "LEFT JOIN sesion_tratamiento s ON s.cita_id = c.id " +
            "WHERE c.estado IN ('ATENDIDA', 'AUSENTE')"
        );
        List<Object> params = new ArrayList<>();
        if (esMedico) {
            String nombreMedico = jdbc.queryForObject("SELECT full_name FROM app_user WHERE username = ?", String.class, auth.getName());
            sql.append(" AND lower(c.profesional) = lower(?)");
            params.add(nombreMedico);
        }
        if (paciente != null && !paciente.isBlank()) {
            sql.append(" AND (lower(p.nombres) LIKE lower(?) OR lower(p.apellidos) LIKE lower(?) OR p.documento LIKE ?)");
            String busqueda = "%" + paciente + "%";
            params.add(busqueda); params.add(busqueda); params.add(busqueda);
        }
        sql.append(" ORDER BY c.inicio DESC LIMIT 50");
        return jdbc.query(sql.toString(), (rs, rn) -> mapCitaDto(rs), params.toArray());
    }

    @GetMapping("/medicos-disponibles")
    public List<MedicoDto> medicosDisponibles(@RequestParam String tipoTratamiento) {
        return jdbc.query(
            "SELECT u.full_name, u.especialidad FROM app_user u JOIN medico_area ma ON ma.user_id = u.id WHERE u.role='MEDICO' AND u.active=TRUE AND ma.tipo_tratamiento = ?",
            (rs, rn) -> new MedicoDto(rs.getString("full_name"), rs.getString("especialidad") != null ? rs.getString("especialidad") : "Medicina General"), tipoTratamiento);
    }

    @GetMapping
    public List<CitaDto> listar(@RequestParam(required = false) LocalDate fecha, Authentication auth) {
        LocalDate dia = fecha == null ? LocalDate.now(ZoneId.of("America/La_Paz")) : fecha;
        boolean esMedico = auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_MEDICO"));

        String baseSql = "SELECT c.id, c.paciente_id, p.nombres || ' ' || p.apellidos AS paciente, p.documento, " +
                         "c.profesional, c.recurso, c.tipo_tratamiento, c.inicio, c.duracion_minutos, c.estado, " +
                         "s.id AS sesion_id, s.estado AS sesion_estado, s.presion, s.temperatura, s.frecuencia_cardiaca AS fc, " +
                         "s.frecuencia_respiratoria AS fr, s.saturacion_oxigeno AS spo2, s.peso, s.talla " +
                         "FROM cita c JOIN paciente p ON p.id = c.paciente_id " +
                         "LEFT JOIN sesion_tratamiento s ON s.cita_id = c.id ";

        if (esMedico) {
            String nombreMedico = jdbc.queryForObject("SELECT full_name FROM app_user WHERE username = ?", String.class, auth.getName());
            return jdbc.query(baseSql + "WHERE DATE(c.inicio) = ? AND lower(c.profesional) = lower(?) ORDER BY c.inicio",
                (rs, rn) -> mapCitaDto(rs), dia, nombreMedico);
        }
        return jdbc.query(baseSql + "WHERE DATE(c.inicio) = ? ORDER BY c.inicio",
                (rs, rn) -> mapCitaDto(rs), dia);
    }

    private CitaDto mapCitaDto(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new CitaDto(
            rs.getLong("id"), rs.getLong("paciente_id"), rs.getString("paciente"), rs.getString("documento"),
            rs.getString("profesional"), rs.getString("recurso"), rs.getString("tipo_tratamiento"),
            rs.getTimestamp("inicio").toLocalDateTime(), rs.getInt("duracion_minutos"), rs.getString("estado"),
            rs.getObject("sesion_id", Long.class), rs.getString("sesion_estado"), rs.getString("presion"),
            rs.getBigDecimal("temperatura"), rs.getObject("fc", Integer.class), rs.getObject("fr", Integer.class),
            rs.getObject("spo2", Integer.class), rs.getBigDecimal("peso"), rs.getBigDecimal("talla")
        );
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA')")
    @Transactional
    public CitaDto crear(@Valid @RequestBody CitaRequest request, Authentication auth) {
        Long id = jdbc.queryForObject("INSERT INTO cita(paciente_id, profesional, recurso, tipo_tratamiento, inicio, duracion_minutos, motivo, creado_por) VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
            Long.class, request.pacienteId(), request.profesional().trim(), request.recurso().trim(),
            request.tipoTratamiento(), Timestamp.valueOf(request.inicio()), request.duracionMinutos(),
            request.motivo(), auth.getName());
        pacienteService.recalcularEstadoClinico(request.pacienteId());
        return buscarPorId(id);
    }

    @PatchMapping("/{id}/reprogramar")
    @PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA')")
    @Transactional
    public CitaDto reprogramar(@PathVariable long id, @Valid @RequestBody ReprogramarRequest request) {
        jdbc.update("UPDATE cita SET inicio=?, duracion_minutos=?, profesional=?, recurso=? WHERE id=?",
            Timestamp.valueOf(request.inicio()), request.duracionMinutos(),
            request.profesional(), request.recurso(), id);
        return buscarPorId(id);
    }

    @PatchMapping("/{id}/estado")
    @Transactional
    public CitaDto cambiarEstado(@PathVariable long id, @RequestBody EstadoRequest request, Authentication auth) {
        boolean esMedico = auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_MEDICO"));
        if (esMedico && !Set.of("ATENDIDA", "AUSENTE").contains(request.estado()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "El médico solo puede marcar como Atendida o Ausente.");
        if (!esMedico && !Set.of("CANCELADA", "CONFIRMADA").contains(request.estado()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Solo el médico puede marcar la cita como Atendida o Ausente.");

        CitaDto cita = buscarPorId(id);
        jdbc.update("UPDATE cita SET estado=? WHERE id=?", request.estado(), id);
        pacienteService.recalcularEstadoClinico(cita.pacienteId());
        return buscarPorId(id);
    }

    private CitaDto buscarPorId(long id) {
        return jdbc.query("SELECT c.id, c.paciente_id, p.nombres || ' ' || p.apellidos AS paciente, p.documento, " +
            "c.profesional, c.recurso, c.tipo_tratamiento, c.inicio, c.duracion_minutos, c.estado, " +
            "s.id AS sesion_id, s.estado AS sesion_estado, s.presion, s.temperatura, s.frecuencia_cardiaca AS fc, " +
            "s.frecuencia_respiratoria AS fr, s.saturacion_oxigeno AS spo2, s.peso, s.talla " +
            "FROM cita c JOIN paciente p ON p.id=c.paciente_id " +
            "LEFT JOIN sesion_tratamiento s ON s.cita_id = c.id WHERE c.id=?",
            (rs, rn) -> mapCitaDto(rs), id).stream().findFirst().orElseThrow();
    }

    public record CitaRequest(@NotNull Long pacienteId, @NotBlank String profesional, @NotBlank String recurso, @NotBlank String tipoTratamiento, @NotNull LocalDateTime inicio, @Min(15) int duracionMinutos, String motivo) {}
    public record ReprogramarRequest(@NotNull LocalDateTime inicio, @Min(15) int duracionMinutos, @NotBlank String profesional, @NotBlank String recurso) {}
    public record EstadoRequest(@NotBlank String estado) {}

    public record CitaDto(long id, long pacienteId, String paciente, String documento, String profesional, String recurso, String tipoTratamiento, LocalDateTime inicio, int duracionMinutos, String estado, Long sesionId, String sesionEstado, String presionEnfermeria, BigDecimal temperaturaEnfermeria, Integer fcEnfermeria, Integer frEnfermeria, Integer spo2Enfermeria, BigDecimal pesoEnfermeria, BigDecimal tallaEnfermeria) {}

    public record SlotDto(String hora, boolean disponible) {}
    public record MedicoDto(String nombre, String especialidad) {}
}