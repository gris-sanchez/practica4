# ----------------------------------------
# Estudiantes: Grisel Sánchez y Saúl Lara
# Profesor: José Canache
# Practica 4
# ----------------------------------------

.data
    msg_green:   .asciiz "\nSemaforo en verde, esperando pulsador\n"
    msg_pressed: .asciiz "Pulsador activado: en 20 segundos, el semaforo cambiara a amarillo\n"
    msg_yellow:  .asciiz "Semaforo en amarillo, en 10 segundos, semaforo en rojo\n"
    msg_red:     .asciiz "Semaforo en rojo, en 30 segundos, semaforo en verde\n"
    
    flag_btn:    .word 0           # Bandera: 1 si se presiono 's', 0 en caso contrario

.text
.globl main
main:
    # Habilitar interrupciones del teclado (MMIO)
    li $t0, 0xFFFF0000             # Direccion de Control del Teclado
    lw $t1, 0($t0)
    ori $t1, $t1, 0x0002           # Activar bit 1 (Interrupt Enable)
    sw $t1, 0($t0)

    # Habilitar interrupciones globales en el Coprocesador 0
    mfc0 $t0, $12                  # Leer registro Status
    ori $t0, $t0, 0x0001           # Activar bit 0 (Global Interrupt Enable)
    mtc0 $t0, $12                  # Escribir en registro Status

reset_green:
    # Reiniciar bandera del boton a 0
    la $t0, flag_btn
    sw $zero, 0($t0)

    # Imprimir estado inicial (Verde)
    li $v0, 4
    la $a0, msg_green
    syscall

wait_for_button:
    # Revisar constantemente si la bandera cambio a 1
    la $t0, flag_btn
    lw $t1, 0($t0)
    beqz $t1, wait_for_button      # Bucle infinito hasta que se presione 's'

    # Imprimir mensaje de pulsador activado
    li $v0, 4
    la $a0, msg_pressed
    syscall

    # Obtener tiempo de inicio para el temporizador de 20s
    li $v0, 30                     # Syscall 30: System Time
    syscall
    move $s0, $a0                  # $s0 guarda el tiempo inicial en milisegundos

timer_20s:
    li $v0, 30
    syscall
    subu $t0, $a0, $s0             # Tiempo actual - Tiempo inicial
    li $t1, 20000                  # 20 segundos = 20000 ms
    blt $t0, $t1, timer_20s        # Esperar hasta cumplir 20s

    # Cambiar a Amarillo
    li $v0, 4
    la $a0, msg_yellow
    syscall

    # Reiniciar tiempo para los 10s
    li $v0, 30
    syscall
    move $s0, $a0

timer_10s:
    li $v0, 30
    syscall
    subu $t0, $a0, $s0
    li $t1, 10000                  # 10 segundos = 10000 ms
    blt $t0, $t1, timer_10s        # Esperar hasta cumplir 10s

    # Cambiar a Rojo
    li $v0, 4
    la $a0, msg_red
    syscall

    # Reiniciar tiempo para los 30s
    li $v0, 30
    syscall
    move $s0, $a0

timer_30s:
    li $v0, 30
    syscall
    subu $t0, $a0, $s0
    li $t1, 30000                  # 30 segundos = 30000 ms
    blt $t0, $t1, timer_30s        # Esperar hasta cumplir 30s

    # Volver al inicio (Verde) y repetir el ciclo
    j reset_green

# ===================================
# Rutina de Servicio de Interrupcion
# ===================================
.kdata
    # Variables para guardar el contexto de los registros
    save_at: .word 0
    save_t0: .word 0
    save_t1: .word 0

.ktext 0x80000180
    # Guardar contexto
    sw $at, save_at
    sw $t0, save_t0
    sw $t1, save_t1

    # Verificar si la excepción proviene del teclado
    mfc0 $k0, $13                  # Leer registro Cause
    andi $k1, $k0, 0x0100          # Comprobar bit 8 (Interrupcion de hardware 0)
    beqz $k1, end_handler

    # Leer el caracter ingresado por teclado
    li $k1, 0xFFFF0004             # Dirección de Datos del Teclado
    lw $t0, 0($k1)

    # Verificar si la tecla presionada es 's' (código ASCII 115)
    li $t1, 115
    bne $t0, $t1, end_handler      # Si no es 's', ignorar y salir

    # Si es 's', activar la bandera
    la $k1, flag_btn
    li $t0, 1
    sw $t0, 0($k1)                 # Guardar 1 en flag_btn

end_handler:
    # Restaurar contexto
    lw $t1, save_t1
    lw $t0, save_t0
    lw $at, save_at

    # Retornar a la ejecución principal
    eret
