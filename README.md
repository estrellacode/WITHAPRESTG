# WithaPrest

Sistema de gestión de préstamos y cobranza desarrollado en Flutter.


# Sobre el proyecto

WithaPrest es una aplicación enfocada en la administración de clientes, préstamos y control de cobranza.  
Además del desarrollo, se realizaron pruebas funcionales para validar el correcto funcionamiento de los flujos principales del sistema.

# Enfoque QA

Durante el desarrollo del sistema, se aplicaron pruebas para asegurar la calidad del software:

- Validación de flujos completos (registro → préstamo → cobranza)
- Pruebas funcionales en módulos clave
- Detección y documentación de errores (bugs)
- Verificación de integraciones con API REST
- Validación de consistencia de datos en base de datos

# Casos de prueba realizados

# Registro de clientes
- Validación de campos obligatorios
- Verificación de almacenamiento correcto en base de datos
- Manejo de errores en datos incompletos

# Creación de préstamos
- Validación de cálculo de cuotas
- Verificación de generación automática de registros
- Pruebas en diferentes tipos de préstamo

# Cobranza
- Validación de pagos aplicados correctamente
- Verificación de actualización de estados (pagado / pendiente)
- Detección de inconsistencias en montos acumulados


# Ejemplos de errores detectados

- Inconsistencias en datos de cobranza en vista `v_lista_cobranza`
- Errores en sincronización de datos con API
- Problemas en validación de estados de cuotas
- Fallos en visualización de información en UI

# Tecnologías utilizadas

- Flutter
- Dart
- Supabase
- SQLite
- APIs REST


# Capturas
<img width="1565" height="861" alt="image" src="https://github.com/user-attachments/assets/15953fda-011e-4c01-a62e-c620ac13618e" />

# Aprendizajes

- Importancia de pruebas funcionales en cada módulo
- Validación de datos antes de persistencia
- Identificación temprana de errores en integraciones
- Mejora en la calidad del software mediante pruebas constantes


## Estado del proyecto

En desarrollo
