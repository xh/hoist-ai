package sample

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class PlainSpringController {

    @GetMapping('/health')
    Map health() {
        return [status: 'ok']
    }
}
