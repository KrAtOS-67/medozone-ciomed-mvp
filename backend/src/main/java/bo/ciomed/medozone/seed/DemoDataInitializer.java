package bo.ciomed.medozone.seed;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;

//@Configuration
@Profile("dev")
public class DemoDataInitializer {

    @Bean
    CommandLineRunner crearUsuariosDeDemostracion(JdbcTemplate jdbc, PasswordEncoder encoder) {
        return args -> {
            String[][] usuarios = {
                    {"admin", "Administrador CIOMED", "ADMIN"},
                    {"recepcion", "Recepción CIOMED", "RECEPCIONISTA"},
                    {"medico", "Profesional Médico", "MEDICO"},
                    {"enfermera", "Personal de Enfermería", "ENFERMERA"}
            };
            String password = System.getenv("MEDOZONE_DEMO_PASSWORD");
            if (password == null || password.isBlank()) {
                throw new IllegalStateException("Debe definir MEDOZONE_DEMO_PASSWORD para el perfil dev.");
            }
            for (String[] usuario : usuarios) {
                Integer existe = jdbc.queryForObject(
                        "SELECT COUNT(*) FROM app_user WHERE username = ?",
                        Integer.class,
                        usuario[0]
                );
                if (existe == null || existe == 0) {
                    jdbc.update(
                            "INSERT INTO app_user(username, password_hash, full_name, role) VALUES (?, ?, ?, ?)",
                            usuario[0], encoder.encode(password), usuario[1], usuario[2]
                    );
                }
            }
        };
    }
}
