package bo.ciomed.medozone.clinica;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/recursos")
@PreAuthorize("hasAnyRole('ADMIN', 'MEDICO', 'ENFERMERA', 'RECEPCIONISTA')") // Todos pueden ver los equipos
public class RecursoController {
    private final JdbcTemplate jdbc;

    public RecursoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // Listar todos los equipos (Todos los roles pueden consultar)
    @GetMapping
    public List<Map<String, Object>> listar(@RequestParam(required = false) String tipo) {
        String sql = "SELECT id, nombre, tipo_tratamiento AS \"tipoTratamiento\", activo FROM recurso ";
        if (tipo != null && !tipo.isEmpty()) {
            sql += "WHERE tipo_tratamiento = ? ORDER BY nombre";
            return jdbc.queryForList(sql, tipo);
        }
        sql += "ORDER BY tipo_tratamiento, nombre";
        return jdbc.queryForList(sql);
    }

    // Crear un nuevo equipo (SOLO ADMIN)
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')") // <--- BARRERA DE SEGURIDAD
    public void crear(@Valid @RequestBody RecursoRequest request) {
        Integer existe = jdbc.queryForObject("SELECT COUNT(*) FROM recurso WHERE LOWER(nombre) = LOWER(?)", Integer.class, request.nombre());
        if (existe != null && existe > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un equipo con ese nombre.");
        }

        jdbc.update("INSERT INTO recurso(nombre, tipo_tratamiento, activo) VALUES (?, ?, true)",
                request.nombre(), request.tipoTratamiento());
    }

    // Activar/Desactivar equipo (SOLO ADMIN)
    @PatchMapping("/{id}/estado")
    @PreAuthorize("hasRole('ADMIN')") // <--- BARRERA DE SEGURIDAD
    public void cambiarEstado(@PathVariable long id, @RequestBody Map<String, Boolean> body) {
        Boolean activo = body.get("activo");
        if (activo == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Falta el campo 'activo'");
        
        jdbc.update("UPDATE recurso SET activo = ? WHERE id = ?", activo, id);
    }

    public record RecursoRequest(@NotBlank String nombre, @NotBlank String tipoTratamiento) {}
}