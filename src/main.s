; Snake in x86_64 (AMD64) assembly, intel syntax
; compiled using NASM
; Written by Yashovardhan Singh on 13-16th jan, 2026
   
; Pre defines for keyboard key codes
%include "include/hardware.inc"

; Raylib Imports
; extern means the reference is external linkage    
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

; Section to store initialised memory
section .data
    ; db stands for declare byte, and when "" are used
    ; it declares a string of bytes. 0 is used as null terminator
    ; equivalent to \0 in c.
    ; db "hi", 0 just means: db 68, 69, 0
    ; the name is just a label here
    window_title db "Snake",0
    char_buf db 0
    curr_len db 1
    curr_dir db 4
    next_dir db 4
    ; dq stands for declare quadword, a word is 16 bits, so quad word
    ; is 16*4 = 64 bits
    fruit dq 0

    ; equ creates a constant in nasm. 20 and 11 are pre computed values
    ; 20 is: screen width in pixels (1280) divided by snake width (64)
    ; 11 is: screen height in pixels (704) divided by snake height (64)
    ; this number just means maximum possible locations for snake to be in
    MAX_NODES equ 20*11

; section to store uninitialised memory
section .bss
    ; resd means reserve dword (double word)
    ; since word is 16 bits, double word is 32 bits
    ; we multiply MAX_NODES by 2, cause we wanna store both x and y coordinate
    ; in the list
    list_start resd MAX_NODES*2

; section that stores all of the code
section .text
    ; This makes _start the entry point of our program
    global _start

; _start is a special label
; we made it global, so this is where our program starts always
_start:
    ; Passing arguments to InitWindow from raylib
    ; argument passing follow system v ABI, since
    ; target platform is linux
    ; mov here is move, move 2nd arg in to first
    mov rdi,1280
    mov rsi,704
    ; lea: load effective address. Calculate address for
    ; window_title and store it in rdx
    lea rdx,[window_title]
    ; call is a special instruction, because it
    ; jumps to the sub routine, but pushes the return
    ; address onto the stack, to resume execution
    call InitWindow

    ; Set FPS
    mov rdi,10
    call SetTargetFPS
    
    call init_list              ; Initialize the list of snake coords
    call spawn_fruit            ; Spawn the fruit

; Labels starting with '.' are local labels
; cannot be accesed outside the parent label (without .)
; unless refered along with parent,
; such as: _start.loop in the case below
.loop:
    call check_input            ; Check for input from keyboard
    call apply_direction        ; apply direction based on keyboard input
    call move_snake             ; move snake accordingly
    call check_bounds           ; check if snake hit edges of the wall
    call check_self_collision   ; check if snake hit itself
    call check_fruit_collision  ; check if snake ate fruit
    call BeginDrawing           ; call raylib function to start drawing frame
    
    xor rdi,rdi                 ; equivalent to mov rdi, 0 except it's faster.
                                ; xor stands for exclusive or operation
                                ; 0 is also black (0x000000) so it works.

    call ClearBackground        ; call raylib function to clear background
                                ; start of every frame
    
    call draw_snake             ; draw the snake
    call draw_fruit             ; draw the fruit
    call EndDrawing             ; raylib function to finish drawing frame,
                                ; presents the batch at the end
    
    call WindowShouldClose      ; check if any window exit events have occured
    test rax,rax                ; test the return value of the function
    jz .loop                    ; if the result of previous test instruction was 0
                                ; then jump back to .loop label. jz stands for jump if zero
    
    call CloseWindow            ; the result of previous test instruction was not 0, so it
                                ; skipped the jump. hence it lands here.
                                ; this conditional jump acts as a branching statement

    mov rax,60                  ; exit syscall (linux)
    xor rdi,rdi                 ; zero out rdi. rdi contains exit code,
                                ; in this case 0 for a successful exit

    syscall                     ; syscall, just look it up

; Initializes the list of coords of the snake body
init_list:
    mov rsi,list_start          ; move pointer to list in rsi
    mov dword [rsi],4           ; set x of first square to 4
    mov dword [rsi+4],4         ; set y of first square to 4
                                ; Here, we use rsi + 4, because in memory
                                ; these 2 numbers are right after another
                                ; and +4 offset because regular int is 32 bits or 4 bytes

    add rsi,8                   ; adding 8, to get to the x for next square (skipping that y)
    mov rcx,MAX_NODES-1         ; -1, to skip the first square/head of the snake
                                ; rcx is a special register
                                ; we'll find out why soon in this function

; Loop body
.loop:
    mov dword [rsi],-1          ; set all position to offscreen location so they don't render
    mov dword [rsi+4],-1        ; inavlid y
    add rsi,8                   ; increment +8 to get next element
    loop .loop                  ; loop instruction looks at the value in rcx register
                                ; if it's 0, break loop
                                ; else loop around to the label mentioned (in this case .loop)

    ret                         ; return execution to where routine was called from

; Routine to draw snake
draw_snake:
    push rbx                    ; according to system v ABI, rbx is non volatile
                                ; so we push it to the stack to preserve
                                ; it's value before the call

    push r12                    ; same reason as pushing rbx
    mov rbx,list_start
    xor r12d,r12d               ; r12d means here to use r12 register to hold data
.loop:
    cmp dword [rbx],-1          ; cmp: compare. dword means a 32 bit value, when we []
                                ; we dereference the value at the memory location
                                ; in this case, rbx points to list_start, so value at list_start

    je .exit                    ; if invalid x for element, then break loop. je: jump if equal

    ; setting up arguments for raylib function call
    mov edi,[rbx]               ; edi is 32 bit version of rdi.
    imul edi,64                 ; multiply by width of square, to align on grid
    mov esi,[rbx+4]             ; esi is 32 bit version of rsi
    imul esi,64                 ; multiply by height of square to align on grid
    mov edx,64                  ; edx is 32 bit rdx, 64 is the width
    mov ecx,64                  ; ecx is 32 it rcx, 64 is the height
    mov r8d,0FFFFFFFFh          ; store color white
    call DrawRectangle          ; call raylib function to draw rectangle

    add rbx,8                   ; set pointer in rbx to next element by adding 8 byte offset
    inc r12d                    ; increment counter
    cmp r12b,[curr_len]         ; check if counter has reached current length of snake
    jne .loop                   ; if not equal then loop again
.exit:
    pop r12                     ; restore value in r12, to what it was before call
    pop rbx                     ; same as above line
    ret

; Rest of the comments are left as an exercise
    
draw_fruit:
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
    ret

check_input:
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
