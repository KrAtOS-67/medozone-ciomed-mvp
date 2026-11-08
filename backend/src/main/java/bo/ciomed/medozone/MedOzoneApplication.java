package bo.ciomed.medozone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MedOzoneApplication {
    public static void main(String[] args) {
        SpringApplication.run(MedOzoneApplication.class, args);
    }
}