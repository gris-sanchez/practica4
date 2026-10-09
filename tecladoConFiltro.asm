# ----------------------------------------
# Estudiantes: Grisel Sánchez y Saúl Lara
# Profesor: José Canache
# Practica 4
# ----------------------------------------

.data
    buffer:      .space 256        # Buffer circular de 256 bytes
    buf_idx:     .word 0           # Índice actual del buffer
    msg_print:   .asciiz "\n--- Contenido del Buffer (20s) ---\n"
    msg_empty:   .asciiz "(Vacio)\n"
    msg_newline: .asciiz "\n"

.text
.globl main
main:
    # Habilitar interrupciones del teclado
    li $t0, 0xFFFF0000             # Dirección de Control del Receptor (Teclado)
    lw $t1, 0($t0)
    ori $t1, $t1, 0x0002           # Activar bit 1 (Interrupt Enable)
    sw $t1, 0($t0)

    # Habilitar interrupciones globales en el Coprocesador 0
    mfc0 $t0, $12                  # Leer registro Status
    ori $t0, $t0, 0x0001           # Activar bit 0 (Global Interrupt Enable)
    mtc0 $t0, $12                  # Escribir en registro Status
	
loop_start:
    # Obtener tiempo de inicio
    li $v0, 30                     # Syscall 30: System Time 
    syscall                        # Retorna milisegundos en $a0 (low) y $a1 (high)
    move $s0, $a0                  # Guardar tiempo inicial en $s0

time_wait_loop:
    # Obtener tiempo actual
    li $v0, 30
    syscall
    
    # Calcular tiempo transcurrido
    subu $t0, $a0, $s0             # $t0 = Tiempo actual - Tiempo inicial
    li $t1, 20000                  # 20 segundos = 20000 milisegundos
    bge $t0, $t1, print_buffer     # Si han pasado 20s, saltar a imprimir
    
    j time_wait_loop               # Seguir esperando

print_buffer:
    # Deshabilitar interrupciones globales brevemente para evitar condiciones de carrera
    mfc0 $t0, $12
    andi $t0, $t0, 0xFFFE
    mtc0 $t0, $12

    # Imprimir mensaje de encabezado
    li $v0, 4
    la $a0, msg_print
    syscall

    # Revisar si el buffer tiene contenido
    la $t0, buf_idx
    lw $t1, 0($t0)                 # $t1 = cantidad de caracteres guardados
    beqz $t1, print_empty

    # Bucle para imprimir el contenido del buffer
    la $t2, buffer
    li $t3, 0                      # Contador de impresión

print_loop:
    bge $t3, $t1, end_print
    add $t4, $t2, $t3              # Calcular dirección: buffer + offset
    lb $a0, 0($t4)                 # Cargar el caracter
    li $v0, 11                     # Syscall 11: Print Character
    syscall
    
    addi $t3, $t3, 1               # Incrementar contador
    j print_loop

print_empty:
    li $v0, 4
    la $a0, msg_empty
    syscall

end_print:
    # Reiniciar el índice del buffer a 0 (vaciar buffer)
    la $t0, buf_idx
    sw $zero, 0($t0)

    # Rehabilitar interrupciones globales
    mfc0 $t0, $12
    ori $t0, $t0, 0x0001
    mtc0 $t0, $12

    # Repetir el ciclo indefinidamente
    j loop_start


# ===================================
# Rutina de Servicio de Interrupción 
# ===================================
.kdata
    # Espacio para guardar el contexto de los registros usados en el kernel
    save_at: .word 0
    save_t0: .word 0

.ktext 0x80000180
    # Guardar contexto
    sw $at, save_at
    sw $t0, save_t0

    # Verificar que la interrupción proviene del teclado
    mfc0 $k0, $13                  # Leer registro Cause
    andi $k1, $k0, 0x0100          # Comprobar bit 8
    beqz $k1, end_handler          # Si no es teclado, salir del handler

    # Leer el caracter del teclado
    li $k1, 0xFFFF0004             # Dirección de Datos del Receptor
    lw $k0, 0($k1)                 # Leer código ASCII ingresado

    # Validar que sea letra mayúscula (A-Z) -> ASCII 65 al 90
    li $k1, 65
    blt $k0, $k1, end_handler      # Si es menor a 'A', descartar
    li $k1, 90
    bgt $k0, $k1, end_handler      # Si es mayor a 'Z', descartar

    # Guardar en el buffer
    la $k1, buf_idx
    lw $t0, 0($k1)                 # Cargar índice actual

    # Manejo del Buffer Circular (Límite 256)
    li $at, 256
    blt $t0, $at, store_char
    li $t0, 0                      # Reiniciar a 0 si llega al límite (Wrap-around)

store_char:
    la $at, buffer
    add $at, $at, $t0              # Dirección base + índice
    sb $k0, 0($at)                 # Guardar el byte (caracter)

    # Actualizar índice
    addi $t0, $t0, 1
    sw $t0, 0($k1)

end_handler:
    # Restaurar contexto
    lw $t0, save_t0
    lw $at, save_at

    # Retornar de la excepción
    eret
