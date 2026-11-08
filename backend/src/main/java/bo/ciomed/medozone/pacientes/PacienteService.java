package bo.ciomed.medozone.pacientes;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class PacienteService {
    private final JdbcTemplate jdbc;

    public PacienteService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void recalcularEstadoClinico(long pacienteId) {
        Integer totalCitas = jdbc.queryForObject("SELECT COUNT(*) FROM cita WHERE paciente_id = ?", Integer.class, pacienteId);
        Integer citasFuturas = jdbc.queryForObject(
                "SELECT COUNT(*) FROM cita WHERE paciente_id = ? AND estado IN ('PROGRAMADA', 'CONFIRMADA') AND inicio > CURRENT_TIMESTAMP",
                Integer.class, pacienteId);

        String estadoActual = jdbc.queryForObject("SELECT estado_clinico FROM paciente WHERE id=?", String.class, pacienteId);
        String nuevoEstado = "NUEVO";

        if (citasFuturas != null && citasFuturas > 0) {
            if (totalCitas != null && totalCitas > 1) {
                nuevoEstado = "EN_SEGUIMIENTO";
            } else {
                nuevoEstado = "EN_TRATAMIENTO";
            }
        } else if (totalCitas != null && totalCitas > 0) {
            nuevoEstado = "EN_SEGUIMIENTO";
        }

        // Respetar el ALTA manual si no hay citas
        if ("ALTA".equals(estadoActual) && (totalCitas == null || totalCitas == 0)) {
            return;
        }
        jdbc.update("UPDATE paciente SET estado_clinico=? WHERE id=?", nuevoEstado, pacienteId);
    }
}