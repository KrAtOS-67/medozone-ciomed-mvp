package bo.ciomed.medozone.common;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.util.Base64;

@Service
public class EmailService {

    private final JavaMailSender mailSender;
    private final String remitente;

    public EmailService(JavaMailSender mailSender, @Value("${app.mail.from:no-reply@ciomed.bo}") String remitente) {
        this.mailSender = mailSender;
        this.remitente = remitente;
    }

    public void enviarFacturaPdf(String destinatario, String nombrePaciente, String numeroFactura, String pdfBase64) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(remitente);
            helper.setTo(destinatario);
            helper.setSubject("Factura CIOMED #" + numeroFactura);
            
            String cuerpo = "Hola " + nombrePaciente + ",\n\n" +
                            "Adjuntamos la factura correspondiente a su tratamiento en CIOMED.\n\n" +
                            "áGracias por su preferencia!\n\n" +
                            "Clínica CIOMED";
            helper.setText(cuerpo);

            // Decodificar el PDF enviado desde Flutter
            byte[] pdfBytes = Base64.getDecoder().decode(pdfBase64);
            helper.addAttachment("Factura_CIOMED_" + numeroFactura + ".pdf", new ByteArrayResource(pdfBytes));

            mailSender.send(message);
        } catch (MessagingException e) {
            throw new RuntimeException("Error al enviar correo: " + e.getMessage());
        }
    }
}