package bo.ciomed.medozone.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import bo.ciomed.medozone.security.JwtService;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final PasswordResetService passwordResetService;

    public AuthController(JdbcTemplate jdbc, PasswordEncoder passwordEncoder, JwtService jwtService, PasswordResetService passwordResetService) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.passwordResetService = passwordResetService;
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        var usuarios = jdbc.query(
                "SELECT username, password_hash, full_name, role FROM app_user WHERE username = ? AND active = TRUE",
                (rs, rowNum) -> new UsuarioLogin(rs.getString("username"), rs.getString("password_hash"), rs.getString("full_name"), rs.getString("role")),
                request.usuario().trim()
        );

        if (usuarios.isEmpty() || !passwordEncoder.matches(request.contrasena(), usuarios.getFirst().passwordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Usuario o contraseña incorrectos.");
        }

        UsuarioLogin usuario = usuarios.getFirst();
        String token = jwtService.generarToken(usuario.username(), usuario.role());
        return new AuthResponse(token, usuario.username(), usuario.fullName(), usuario.role());
    }

    @GetMapping("/me")
    public PerfilResponse perfil(Authentication authentication) {
        var perfiles = jdbc.query(
                "SELECT username, full_name, role FROM app_user WHERE username=? AND active=TRUE",
                (rs, rowNum) -> new PerfilResponse(rs.getString("username"), rs.getString("full_name"), rs.getString("role")), authentication.getName()
        );
        if (perfiles.isEmpty()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "La cuenta ya no está activa.");
        return perfiles.getFirst();
    }

    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void forgotPassword(@Valid @RequestBody ForgotPasswordRequest req, HttpServletRequest http) {
        passwordResetService.solicitar(req.usuario(), ipCliente(http));
    }

    @PostMapping("/verify-code")
    public void verifyCode(@Valid @RequestBody VerifyCodeRequest req) {
        passwordResetService.verificarCodigo(req.codigo());
    }

    @PostMapping("/reset-password")
    public void resetPassword(@Valid @RequestBody ResetPasswordRequest req) {
        passwordResetService.restablecer(req.token(), req.nuevaContrasena());
    }

    private static String ipCliente(HttpServletRequest req) {
        String xff = req.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) return xff.split(",")[0].trim();
        return req.getRemoteAddr();
    }

    public record PerfilResponse(String usuario, String nombre, String rol) {}
    public record LoginRequest(@NotBlank String usuario, @NotBlank String contrasena) {}
    public record AuthResponse(String token, String usuario, String nombre, String rol) {}
    public record ForgotPasswordRequest(@NotBlank String usuario) {}
    public record VerifyCodeRequest(@NotBlank String codigo) {} // 🚀 NUEVO
    public record ResetPasswordRequest(@NotBlank String token, @NotBlank @Size(min = 8) String nuevaContrasena) {}
    private record UsuarioLogin(String username, String passwordHash, String fullName, String role) {}
}