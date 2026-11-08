package bo.ciomed.medozone.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;

@Service
public class PasswordResetService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetService.class);

    private static final SecureRandom RNG = new SecureRandom();
    private static final Duration VALIDEZ = Duration.ofMinutes(10);
    private static final int MAX_SOLICITUDES_15MIN = 3;

    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;
    private final JavaMailSender mailSender;
    private final String remitente;
    private final boolean envioHabilitado;

    public PasswordResetService(
            JdbcTemplate jdbc,
            PasswordEncoder passwordEncoder,
            JavaMailSender mailSender,
            @Value("${app.mail.from:no-reply@ciomed.bo}") String remitente,
            @Value("${app.mail.enabled:false}") boolean envioHabilitado) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.mailSender = mailSender;
        this.remitente = remitente;
        this.envioHabilitado = envioHabilitado;
    }

    @Transactional
    public void solicitar(String usuario, String ip) {
        var filas = jdbc.query(
            "SELECT id, email, full_name FROM app_user WHERE username = ? AND active = TRUE",
            (rs, n) -> new Object[]{rs.getLong("id"), rs.getString("email"), rs.getString("full_name")},
            usuario == null ? "" : usuario.trim());

        if (filas.isEmpty()) return;

        Long userId = (Long) filas.getFirst()[0];
        String email = (String) filas.getFirst()[1];
        String nombre = (String) filas.getFirst()[2];

        if (email == null || email.isBlank()) return;

        Long recientes = jdbc.queryForObject(
            "SELECT COUNT(*) FROM password_reset_token WHERE user_id = ? AND created_at > CURRENT_TIMESTAMP - INTERVAL '15 minutes'",
            Long.class, userId);
        if (recientes != null && recientes >= MAX_SOLICITUDES_15MIN) {
            log.warn("Rate limit alcanzado para usuario={}", usuario);
            return;
        }

        jdbc.update("UPDATE password_reset_token SET used = TRUE, used_at = CURRENT_TIMESTAMP WHERE user_id = ? AND used = FALSE", userId);

        String codigo = String.format("%06d", RNG.nextInt(1_000_000));
        String tokenHash = sha256Hex(codigo);

        jdbc.update(
            "INSERT INTO password_reset_token(user_id, token_hash, expires_at, created_ip) VALUES (?, ?, ?, ?)",
            userId, tokenHash, java.sql.Timestamp.from(Instant.now().plus(VALIDEZ)), ip);

        if (envioHabilitado) {
            try {
                var msg = new SimpleMailMessage();
                msg.setFrom(remitente);
                msg.setTo(email);
                msg.setSubject("Tu código de verificación ✉️ CIOMED");
                msg.setText("Hola " + (nombre == null ? "" : nombre) + ",\n\n" +
                    "Tu código de verificación es:\n\n" +
                    "        " + codigo + "\n\n" +
                    "Válido por 10 minutos. Un solo uso.\n\n" +
                    "Si no lo solicitaste, ignora este mensaje. Tu contraseña no cambió.\n\n" +
                    "✉️ CIOMED");
                mailSender.send(msg);
                log.info("Correo de recuperación enviado a {}", email);
            } catch (Exception e) {
                log.error("Falló el envío del correo de recuperación a {}: {}", email, e.getMessage());
            }
        } else {
            log.warn("[DEV] Código de recuperación para {}: {}", usuario, codigo);
        }
    }

    @Transactional(readOnly = true)
    public void verificarCodigo(String codigo) {
        if (codigo == null || codigo.isBlank())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código inválido.");

        String hash = sha256Hex(codigo.trim());

        Long count = jdbc.queryForObject(
            "SELECT COUNT(*) FROM password_reset_token WHERE token_hash = ? AND used = FALSE AND expires_at > CURRENT_TIMESTAMP",
            Long.class, hash);

        if (count == null || count == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código es inválido o ha expirado.");
        }
    }

    @Transactional
    public void restablecer(String codigo, String nuevaContrasena) {
        if (codigo == null || codigo.isBlank())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Código inválido.");

        if (nuevaContrasena == null || nuevaContrasena.length() < 8)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La contraseña debe tener al menos 8 caracteres.");

        String hash = sha256Hex(codigo.trim());

        var filas = jdbc.query(
            "SELECT id, user_id FROM password_reset_token WHERE token_hash = ? AND used = FALSE AND expires_at > CURRENT_TIMESTAMP",
            (rs, n) -> new long[]{rs.getLong("id"), rs.getLong("user_id")}, hash);

        if (filas.isEmpty())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código es inválido o ha expirado.");

        long tokenId = filas.getFirst()[0];
        long userId = filas.getFirst()[1];

        int actualizados = jdbc.update("UPDATE password_reset_token SET used = TRUE, used_at = CURRENT_TIMESTAMP WHERE id = ? AND used = FALSE", tokenId);
        if (actualizados == 0)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código ya fue utilizado.");

        jdbc.update("UPDATE app_user SET password_hash = ? WHERE id = ? AND active = TRUE", passwordEncoder.encode(nuevaContrasena), userId);
        jdbc.update("UPDATE password_reset_token SET used = TRUE, used_at = CURRENT_TIMESTAMP WHERE user_id = ? AND used = FALSE", userId);

        log.info("Contraseña restablecida para userId={}", userId);
    }

    private static String sha256Hex(String s) {
        try {
            var md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}