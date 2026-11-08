package bo.ciomed.medozone.reportes;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/reportes")
@PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA')")
public class ReporteController {
    private final JdbcTemplate jdbc;

    public ReporteController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/resumen")
    public Map<String, Object> resumenDiario() {
        Map<String, Object> r = new HashMap<>();
        r.put("pacientesActivos", jdbc.queryForObject("SELECT COUNT(*) FROM paciente WHERE activo=TRUE", Integer.class));
        r.put("citasDeHoy", jdbc.queryForObject("SELECT COUNT(*) FROM cita WHERE DATE(inicio) = CURRENT_DATE", Integer.class));
        r.put("sesionesDeHoy", jdbc.queryForObject("SELECT COUNT(*) FROM sesion_tratamiento WHERE DATE(registrado_en) = CURRENT_DATE", Integer.class));
        return r;
    }

    @GetMapping("/usuarios")
    public List<Map<String, Object>> usuarios() {
        return jdbc.queryForList(
            "SELECT u.id, u.username, u.full_name, u.email, u.telefono, u.role, u.especialidad, " +
            "CASE WHEN u.active THEN 'ACTIVO' ELSE 'INACTIVO' END AS estado, " +
            "TO_CHAR(u.created_at, 'DD/MM/YYYY') AS fecha_registro, " +
            "COALESCE(STRING_AGG(ma.tipo_tratamiento, ', '), 'N/A') AS areas " +
            "FROM app_user u LEFT JOIN medico_area ma ON ma.user_id = u.id " +
            "GROUP BY u.id ORDER BY u.role, u.full_name"
        );
    }

    @GetMapping("/pacientes")
    public List<Map<String, Object>> pacientes() {
        return jdbc.queryForList(
            "SELECT id, nombres, apellidos, documento, telefono, email, fecha_nacimiento, " +
            "estado_clinico, CASE WHEN activo THEN 'ACTIVO' ELSE 'INACTIVO' END AS estado " +
            "FROM paciente ORDER BY apellidos, nombres"
        );
    }

    @GetMapping("/sesiones")
    public List<Map<String, Object>> sesiones() {
        return jdbc.queryForList(
            "SELECT s.id, p.nombres || ' ' || p.apellidos AS paciente, c.tipo_tratamiento, " +
            "TO_CHAR(s.registrado_en, 'DD/MM/YYYY HH24:MI') AS fecha, s.dosis, s.presion, s.temperatura, " +
            "s.frecuencia_cardiaca, s.frecuencia_respiratoria, s.saturacion_oxigeno, s.peso, s.talla, " +
            "s.duracion_minutos, s.observaciones, s.registrado_por, s.estado " +
            "FROM sesion_tratamiento s JOIN cita c ON c.id = s.cita_id JOIN paciente p ON p.id = c.paciente_id " +
            "ORDER BY s.registrado_en DESC"
        );
    }

    @GetMapping("/deudas")
    public List<Map<String, Object>> deudas() {
        return jdbc.queryForList(
            "SELECT f.id, p.nombres || ' ' || p.apellidos AS paciente, p.telefono, p.email, " +
            "f.total, COALESCE((SELECT SUM(monto) FROM pago WHERE factura_id = f.id), 0) AS pagado, " +
            "(f.total - COALESCE((SELECT SUM(monto) FROM pago WHERE factura_id = f.id), 0)) AS saldo, " +
            "TO_CHAR(f.emitida_en, 'DD/MM/YYYY') AS fecha_emision " +
            "FROM factura f JOIN paciente p ON p.id = f.paciente_id " +
            "WHERE f.estado = 'PENDIENTE' ORDER BY saldo DESC"
        );
    }

    @GetMapping("/estadisticas")
    public Map<String, Object> estadisticas(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {

        Map<String, Object> res = new HashMap<>();

        List<Map<String, Object>> pacientesPorTratamiento = jdbc.queryForList(
            "SELECT c.tipo_tratamiento as tipo, COUNT(DISTINCT c.paciente_id) as cantidad " +
            "FROM cita c WHERE DATE(c.inicio) BETWEEN ? AND ? AND c.estado != 'CANCELADA' " +
            "GROUP BY c.tipo_tratamiento", inicio, fin);
        res.put("pacientesPorTratamiento", pacientesPorTratamiento);

        // Ranking solo con usuarios ACTIVOS
        List<Map<String, Object>> rankingProfesionales = jdbc.queryForList(
            "SELECT u.full_name as profesional, COUNT(s.id) as total " +
            "FROM sesion_tratamiento s JOIN app_user u ON u.username = s.registrado_por " +
            "WHERE DATE(s.registrado_en) BETWEEN ? AND ? AND u.active = TRUE " +
            "GROUP BY u.full_name ORDER BY total DESC", inicio, fin);
        res.put("rankingProfesionales", rankingProfesionales);

        Double pagados = jdbc.queryForObject("SELECT COALESCE(SUM(monto), 0) FROM pago WHERE DATE(pagado_en) BETWEEN ? AND ?", Double.class, inicio, fin);
        Double pendientes = jdbc.queryForObject("SELECT COALESCE(SUM(total), 0) FROM factura WHERE DATE(emitida_en) BETWEEN ? AND ? AND estado = 'PENDIENTE'", Double.class, inicio, fin);

        List<Map<String, Object>> ingresosDiarios = jdbc.queryForList(
            "SELECT DATE(pagado_en) as fecha, SUM(monto) as total FROM pago WHERE DATE(pagado_en) BETWEEN ? AND ? " +
            "GROUP BY DATE(pagado_en) ORDER BY DATE(pagado_en)", inicio, fin);

        Map<String, Object> ingresos = new HashMap<>();
        ingresos.put("pagados", pagados);
        ingresos.put("pendientes", pendientes);
        ingresos.put("diarios", ingresosDiarios);
        res.put("ingresos", ingresos);

        Integer atendidas = jdbc.queryForObject("SELECT COUNT(*) FROM cita WHERE DATE(inicio) BETWEEN ? AND ? AND estado = 'ATENDIDA'", Integer.class, inicio, fin);
        Integer ausentes = jdbc.queryForObject("SELECT COUNT(*) FROM cita WHERE DATE(inicio) BETWEEN ? AND ? AND estado = 'AUSENTE'", Integer.class, inicio, fin);
        Integer canceladas = jdbc.queryForObject("SELECT COUNT(*) FROM cita WHERE DATE(inicio) BETWEEN ? AND ? AND estado = 'CANCELADA'", Integer.class, inicio, fin);

        Map<String, Object> cumplimiento = new HashMap<>();
        cumplimiento.put("atendidas", atendidas);
        cumplimiento.put("ausentes", ausentes);
        cumplimiento.put("canceladas", canceladas);
        res.put("cumplimiento", cumplimiento);

        List<Map<String, Object>> pacientesHoy = jdbc.queryForList(
            "SELECT p.nombres || ' ' || p.apellidos as paciente, c.profesional, c.inicio, c.estado " +
            "FROM cita c JOIN paciente p ON p.id = c.paciente_id WHERE DATE(c.inicio) = CURRENT_DATE ORDER BY c.inicio");
        res.put("pacientesHoy", pacientesHoy);

        return res;
    }
}