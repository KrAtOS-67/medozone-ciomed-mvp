package bo.ciomed.medozone.users;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;

@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);
    private static final Set<String> ROLES_VALIDOS = Set.of("ADMIN", "MEDICO", "ENFERMERA", "RECEPCIONISTA");

    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;

    public UserService(JdbcTemplate jdbc, PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
    }

    public List<UserDto> listar() {
        List<UserDto> users = jdbc.query(
                "SELECT id, username, full_name, email, telefono, especialidad, role, active, created_at " +
                "FROM app_user ORDER BY active DESC, role, username",
                (rs, n) -> new UserDto(
                        rs.getLong("id"), rs.getString("username"), rs.getString("full_name"),
                        rs.getString("email"), rs.getString("telefono"), rs.getString("especialidad"), rs.getString("role"),
                        rs.getBoolean("active"),
                        rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().toString() : null,
                        null 
                )
        );
        
        for (int i = 0; i < users.size(); i++) {
            UserDto u = users.get(i);
            if ("MEDICO".equals(u.role())) {
                List<String> areas = jdbc.queryForList("SELECT tipo_tratamiento FROM medico_area WHERE user_id=?", String.class, u.id());
                users.set(i, new UserDto(u.id(), u.username(), u.fullName(), u.email(), u.telefono(), u.especialidad(), u.role(), u.active(), u.createdAt(), areas));
            }
        }
        return users;
    }

    @Transactional
    public UserDto crear(CreateUserRequest req) {
        validarUsername(req.username());
        validarPassword(req.password());
        validarRol(req.role());

        Long existentes = jdbc.queryForObject("SELECT COUNT(*) FROM app_user WHERE username = ?", Long.class, req.username().trim());
        if (existentes != null && existentes > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un usuario con ese nombre.");
        }

        Long id = jdbc.queryForObject(
                "INSERT INTO app_user(username, password_hash, full_name, email, telefono, especialidad, role, active) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, TRUE) RETURNING id",
                Long.class, req.username().trim(), passwordEncoder.encode(req.password()), req.fullName().trim(),
                (req.email() == null || req.email().isBlank()) ? null : req.email().trim(),
                (req.telefono() == null || req.telefono().isBlank()) ? null : req.telefono().trim(),
                (req.especialidad() == null || req.especialidad().isBlank()) ? null : req.especialidad().trim(),
                req.role().toUpperCase()
        );

        guardarAreas(id, req.role(), req.areas());
        log.info("Usuario creado: {} ({})", req.username(), req.role());
        return buscarPorId(id);
    }

    @Transactional
    public UserDto actualizar(long id, UpdateUserRequest req, String actorUsername) {
        UserDto actual = buscarPorId(id);
        validarRol(req.role());

        if (actual.username().equals(actorUsername) && !actual.role().equalsIgnoreCase(req.role())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No puedes cambiar tu propio rol.");
        }

        jdbc.update("UPDATE app_user SET full_name=?, email=?, telefono=?, especialidad=?, role=? WHERE id=?",
                req.fullName().trim(),
                (req.email() == null || req.email().isBlank()) ? null : req.email().trim(),
                (req.telefono() == null || req.telefono().isBlank()) ? null : req.telefono().trim(),
                (req.especialidad() == null || req.especialidad().isBlank()) ? null : req.especialidad().trim(),
                req.role().toUpperCase(), id);

        jdbc.update("DELETE FROM medico_area WHERE user_id=?", id);
        guardarAreas(id, req.role(), req.areas());

        return buscarPorId(id);
    }

    private void guardarAreas(long userId, String role, List<String> areas) {
        if ("MEDICO".equalsIgnoreCase(role)) {
            // Si por alguna razon no envian areas, le asignamos Ozonoterapia por defecto
            if (areas == null || areas.isEmpty()) {
                jdbc.update("INSERT INTO medico_area(user_id, tipo_tratamiento) VALUES (?, ?) ON CONFLICT DO NOTHING", userId, "OZONOTERAPIA");
            } else {
                for (String area : areas) {
                    jdbc.update("INSERT INTO medico_area(user_id, tipo_tratamiento) VALUES (?, ?) ON CONFLICT DO NOTHING", userId, area);
                }
            }
        }
    }

    @Transactional
    public UserDto cambiarEstado(long id, boolean activo, String actorUsername) {
        UserDto actual = buscarPorId(id);
        if (actual.username().equals(actorUsername) && !activo) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No puedes desactivarte a ti mismo.");
        jdbc.update("UPDATE app_user SET active=? WHERE id=?", activo, id);
        return buscarPorId(id);
    }

    @Transactional
    public void resetPassword(long id, String nuevaContrasena) {
        validarPassword(nuevaContrasena);
        jdbc.update("UPDATE app_user SET password_hash=? WHERE id=?", passwordEncoder.encode(nuevaContrasena), id);
    }

    private UserDto buscarPorId(long id) {
        UserDto u = jdbc.query("SELECT id, username, full_name, email, telefono, especialidad, role, active, created_at FROM app_user WHERE id=?",
                (rs, n) -> new UserDto(rs.getLong("id"), rs.getString("username"), rs.getString("full_name"), rs.getString("email"), rs.getString("telefono"), rs.getString("especialidad"), rs.getString("role"), rs.getBoolean("active"),
                        rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().toString() : null, null), id)
                .stream().findFirst().orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado."));
        
        List<String> areas = jdbc.queryForList("SELECT tipo_tratamiento FROM medico_area WHERE user_id=?", String.class, id);
        return new UserDto(u.id(), u.username(), u.fullName(), u.email(), u.telefono(), u.especialidad(), u.role(), u.active(), u.createdAt(), areas);
    }

    private void validarUsername(String s) {
        if (s == null || s.trim().length() < 3) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mínimo 3 caracteres.");
        if (!s.trim().matches("^[a-zA-Z0-9._-]+$")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Solo letras, números, . _ -");
    }

    private void validarPassword(String s) {
        if (s == null || s.length() < 8) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mínimo 8 caracteres.");
    }

    private void validarRol(String rol) {
        if (rol == null || !ROLES_VALIDOS.contains(rol.toUpperCase())) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Rol inválido.");
    }

    public record UserDto(long id, String username, String fullName, String email, String telefono, String especialidad, String role, boolean active, String createdAt, List<String> areas) {}
    public record CreateUserRequest(String username, String password, String fullName, String email, String telefono, String especialidad, String role, List<String> areas) {}
    public record UpdateUserRequest(String fullName, String email, String telefono, String especialidad, String role, List<String> areas) {}
    public record ResetPasswordRequest(String nuevaContrasena) {}
}