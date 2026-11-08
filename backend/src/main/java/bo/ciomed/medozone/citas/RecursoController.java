package bo.ciomed.medozone.citas;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/recursos")
@PreAuthorize("hasAnyRole('ADMIN','RECEPCIONISTA','MEDICO','ENFERMERA')")
public class RecursoController {
    private final JdbcTemplate jdbc;

    public RecursoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<RecursoDto> listar(@RequestParam(required = false) String tipo) {
        String sql = "SELECT id, nombre, tipo_tratamiento FROM recurso WHERE activo = TRUE";
        if (tipo != null && !tipo.isBlank()) {
            sql += " AND (tipo_tratamiento = ? OR tipo_tratamiento = 'AMBOS')";
            return jdbc.query(sql, (rs, rn) -> new RecursoDto(rs.getLong("id"), rs.getString("nombre"), rs.getString("tipo_tratamiento")), tipo);
        }
        return jdbc.query(sql, (rs, rn) -> new RecursoDto(rs.getLong("id"), rs.getString("nombre"), rs.getString("tipo_tratamiento")));
    }

    public record RecursoDto(long id, String nombre, String tipoTratamiento) {}
}