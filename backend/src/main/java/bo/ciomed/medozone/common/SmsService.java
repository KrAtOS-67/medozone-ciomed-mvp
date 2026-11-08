package bo.ciomed.medozone.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class SmsService {
    private static final Logger log = LoggerFactory.getLogger(SmsService.class);

    public void enviarFacturaWhatsApp(String telefono, String paciente, String concepto, String total, String pagado, String saldo) {
        if (telefono == null || telefono.isBlank()) {
            log.warn("No se puede enviar WhatsApp: el paciente {} no tiene telefono registrado.", paciente);
            return;
        }

        String mensaje = String.format(
            "\n=========================================\n" +
            "         CIOMED - COMPROBANTE\n" +
            "=========================================\n" +
            "Paciente: %s\n" +
            "Detalle: %s\n" +
            "-----------------------------------------\n" +
            "TOTAL:    Bs. %s\n" +
            "PAGADO:   Bs. %s\n" +
            "SALDO:    Bs. %s\n" +
            "=========================================\n" +
            "áGracias por su preferencia!\n", 
            paciente, concepto, total, pagado, saldo
        );
        
        // Simulacion de envio a WhatsApp (En produccion se integraria con la API de Meta o Twilio)
        log.info("WHATSAPP ENVIADO A {}: {}", telefono, mensaje);
    }
}