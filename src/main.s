; Pre defines for keyboard key codes
%include "include/hardware.inc"

; Raylib Imports
extern InitWindow
extern SetTargetFPS
extern IsKeyDown
extern BeginDrawing
extern ClearBackground
extern DrawRectangle
extern EndDrawing
extern WindowShouldClose
extern CloseWindow
extern GetRandomValue

section .data
    window_title db "Snake",0
    char_buf db 0
    curr_len db 1
    curr_dir db 4
    next_dir db 4
    fruit dq 0

    MAX_NODES equ 20*11

section .bss
    list_start resd MAX_NODES*2

section .text
    global _start

_start:
    mov rdi,1280
    mov rsi,704
    lea rdx,[window_title]
    call InitWindow
    mov rdi,5
    call SetTargetFPS
    call init_list
    call spawn_fruit
.loop:
    call check_input
    call apply_direction
    call move_snake
    call check_bounds
    call check_self_collision
    call check_fruit_collision
    call BeginDrawing
    xor rdi,rdi
    call ClearBackground
    call draw_snake
    call draw_fruit
    call EndDrawing
    call WindowShouldClose
    test rax,rax
    jz .loop
    call CloseWindow
    mov rax,60
    xor rdi,rdi
    syscall

init_list:
    push rbp
    mov rbp,rsp
    mov rsi,list_start
    mov dword [rsi],4
    mov dword [rsi+4],4
    add rsi,8
    mov rcx,MAX_NODES-1
.loop:
    mov dword [rsi],-1
    mov dword [rsi+4],-1
    add rsi,8
    loop .loop
    pop rbp
    ret

draw_snake:
    push rbp
    mov rbp,rsp
    push rbx
    push r12
    mov rbx,list_start
    xor r12d,r12d
.loop:
    cmp dword [rbx],-1
    je .exit
    mov edi,[rbx]
    imul edi,64
    mov esi,[rbx+4]
    imul esi,64
    mov edx,64
    mov ecx,64
    mov r8d,0FFFFFFFFh
    call DrawRectangle
    add rbx,8
    inc r12d
    cmp r12b,[curr_len]
    jne .loop
.exit:
    pop r12
    pop rbx
    pop rbp
    ret

draw_fruit:
    push rbp
    mov rbp,rsp
    mov edi,[fruit]
    imul edi,64
    add edi,16
    mov esi,[fruit+4]
    imul esi,64
    add esi,16
    mov edx,32
    mov ecx,32
    mov r8d,0FF0000FFh
    call DrawRectangle
    pop rbp
    ret

check_input:
    push rbp
    mov rbp,rsp
    mov rdi,KEY_W
    call IsKeyDown
    test rax,rax
    jnz .up
    mov rdi,KEY_S
    call IsKeyDown
    test rax,rax
    jnz .down
    mov rdi,KEY_A
    call IsKeyDown
    test rax,rax
    jnz .left
    mov rdi,KEY_D
    call IsKeyDown
    test rax,rax
    jnz .right
    jmp .exit
.up:
    mov byte [next_dir],1
    jmp .exit
.down:
    mov byte [next_dir],3
    jmp .exit
.left:
    mov byte [next_dir],2
    jmp .exit
.right:
    mov byte [next_dir],4
.exit:
    pop rbp
    ret

apply_direction:
    mov al,[curr_dir]
    mov bl,[next_dir]
    cmp al,1
    je .reject_down
    cmp al,3
    je .reject_up
    cmp al,2
    je .reject_right
    cmp al,4
    je .reject_left
    jmp .apply
.reject_down:
    cmp bl,3
    je .exit
    jmp .apply
.reject_up:
    cmp bl,1
    je .exit
    jmp .apply
.reject_right:
    cmp bl,4
    je .exit
    jmp .apply
.reject_left:
    cmp bl,2
    je .exit
.apply:
    mov [curr_dir],bl
.exit:
    ret

move_snake:
    push rbp
    mov rbp,rsp
    push rbx
    movzx rcx,byte [curr_len]
    lea rbx,[list_start+rcx*8-8]
.loop:
    cmp rcx,1
    jbe .head
    mov eax,[rbx-8]
    mov [rbx],eax
    mov eax,[rbx-4]
    mov [rbx+4],eax
    sub rbx,8
    dec rcx
    jmp .loop
.head:
    mov rbx,list_start
    cmp byte [curr_dir],1
    je .up
    cmp byte [curr_dir],2
    je .left
    cmp byte [curr_dir],3
    je .down
    cmp byte [curr_dir],4
    je .right
    jmp .exit
.up:
    dec dword [rbx+4]
    jmp .exit
.down:
    inc dword [rbx+4]
    jmp .exit
.left:
    dec dword [rbx]
    jmp .exit
.right:
    inc dword [rbx]
.exit:
    pop rbx
    pop rbp
    ret

check_bounds:
    cmp dword [list_start],0
    jl .reset
    cmp dword [list_start+4],0
    jl .reset
    cmp dword [list_start],20
    jge .reset
    cmp dword [list_start+4],11
    jge .reset
    ret
.reset:
    call init_list
    call spawn_fruit
    mov byte [curr_len],1
    mov byte [curr_dir],4
    mov byte [next_dir],4
    ret

check_self_collision:
    push rbx
    push r12
    movzx eax,byte [curr_len]
    mov ebx,[list_start]
    mov ecx,[list_start+4]
    lea rdx,[list_start+8]
    mov r12d,1
.loop:
    cmp r12d,eax
    jge .exit
    cmp dword [rdx],ebx
    jne .next
    cmp dword [rdx+4],ecx
    je .reset
.next:
    add rdx,8
    inc r12d
    jmp .loop
.reset:
    call init_list
    call spawn_fruit
    mov byte [curr_len],1
    mov byte [curr_dir],4
    mov byte [next_dir],4
.exit:
    pop r12
    pop rbx
    ret

check_fruit_collision:
    mov eax,[list_start]
    cmp eax,[fruit]
    jne .exit
    mov eax,[list_start+4]
    cmp eax,[fruit+4]
    jne .exit
    call grow_snake
    call spawn_fruit
.exit:
    ret

grow_snake:
    movzx ecx,byte [curr_len]
    lea rsi,[list_start+rcx*8-8]
    mov eax,[rsi]
    mov [rsi+8],eax
    mov eax,[rsi+4]
    mov [rsi+12],eax
    inc byte [curr_len]
    ret

spawn_fruit:
.try:
    mov edi,0
    mov esi,19
    call GetRandomValue
    mov ebx,eax
    mov edi,0
    mov esi,10
    call GetRandomValue
    mov ecx,eax
    movzx edx,byte [curr_len]
    mov rsi,list_start
.check:
    test edx,edx
    jz .ok
    cmp [rsi],ebx
    jne .next
    cmp [rsi+4],ecx
    je .try
.next:
    add rsi,8
    dec edx
    jmp .check
.ok:
    mov [fruit],ebx
    mov [fruit+4],ecx
    ret
