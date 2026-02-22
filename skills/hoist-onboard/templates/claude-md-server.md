
## Server-Side (hoist-core / Grails)

- Grails application with the hoist-core plugin providing server-side framework
- Controllers extend `BaseController`, services extend `BaseService`
- Server configuration managed via `configService` and the Admin UI config entries
- Groovy/Grails conventions: convention-over-configuration, GORM for persistence
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`
