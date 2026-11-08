package bo.ciomed.medozone.users;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@PreAuthorize("hasRole('ADMIN')")
public class UserController {

    private final UserService service;

    public UserController(UserService service) {
        this.service = service;
    }

    @GetMapping
    public List<UserService.UserDto> listar() {
        return service.listar();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserService.UserDto crear(@Valid @RequestBody UserService.CreateUserRequest req) {
        return service.crear(req);
    }

    @PutMapping("/{id}")
    public UserService.UserDto actualizar(
            @PathVariable long id,
            @Valid @RequestBody UserService.UpdateUserRequest req,
            Authentication auth) {
        return service.actualizar(id, req, auth.getName());
    }

    @PatchMapping("/{id}/activar")
    public UserService.UserDto activar(@PathVariable long id, Authentication auth) {
        return service.cambiarEstado(id, true, auth.getName());
    }

    @PatchMapping("/{id}/desactivar")
    public UserService.UserDto desactivar(@PathVariable long id, Authentication auth) {
        return service.cambiarEstado(id, false, auth.getName());
    }

    @PatchMapping("/{id}/reset-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resetPassword(
            @PathVariable long id,
            @Valid @RequestBody UserService.ResetPasswordRequest req) {
        service.resetPassword(id, req.nuevaContrasena());
    }
}