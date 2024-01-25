; Программа выводит на экран прямоугольники для выбора толщины линии и палитру из основных 16 цветов.
; Пользователь имеет возможность выбрать тот или иной цвет и толщину линии и затем рисовать этим цветом на окне белого цвета.
.286
.model tiny
.code
org 100h

; ---------------------
; ----- константы -----
; ---------------------

; Для работы с видеопаматью
VGA_SEG  = 0A000h
SEG_SIZE = 0FFFFh

SCREEN_WIDTH  = 640
SCREEN_HEIGHT = 480

; Кнопки выбора цвета и размера точки
BUTTON_SIZE = 16
BUTTON_GAP = 8
HALF_BUTTON_SIZE = BUTTON_SIZE / 2
HALF_BUTTON_GAP = BUTTON_GAP / 2

; Параметры цветов
TOTAL_COLORS = 15
DEFAULT_COLOR = 1
COLOR_ROW = 8
COLOR_COL = 6

; Размер точки и линий
TOTAL_SIZES = 3
DEFAULT_SIZE = 1
SIZE_ROW = 8
SIZE_COL = 610

; Скан-коды клавиш
KEY_ESC = 01h
KEY_C = 2Eh

UP_ARROW = 48h
DOWN_ARROW = 50h
LEFT_ARROW = 4Bh
RIGHT_ARROW = 4Dh

UP_ARROW_CTRL = 8Dh
DOWN_ARROW_CTRL = 91h
LEFT_ARROW_CTRL = 73h
RIGHT_ARROW_CTRL = 74h

UP_ARROW_ALT = 98h
DOWN_ARROW_ALT = 0A0h
LEFT_ARROW_ALT = 9Bh
RIGHT_ARROW_ALT = 9Dh

; Ограничения передвижения курсора
MIN_ROW = COLOR_ROW + BUTTON_SIZE + HALF_BUTTON_GAP + 1
MAX_ROW = SCREEN_HEIGHT - 1
MIN_COL = TOTAL_SIZES
MAX_COL = SIZE_COL - HALF_BUTTON_GAP - 2


; ------------------------------
; ----- основная программа -----
; ------------------------------
start:			mov ax, 12h					; Установка видеорежима: VGA, 640х480, 16 цветов
				int 10h

				call initScreen

@@getNextKey:	call getKey
				cmp ah, KEY_ESC
				je @@allDone
				cmp ah, KEY_C
				je @@clearScreen
				call manageColors
				call manageSizes
				call drawPoint
				jmp short @@getNextKey
				
@@clearScreen:	call initScreen
				jmp short @@getNextKey

@@allDone:		mov ax, 03h					; Выход из графического видеорежима
				int 10h

				mov ax, 4C00h				; Завершение работы программы
				int 21h
; =====================

; ---------------------
; ----- процедуры -----
; ---------------------

; -----
; Сброс содержимого экрана (очистка экрана)
initScreen		proc near
				call clearScreen
				call drawColors
				call drawSelectColor
				call drawSizes
				call drawSelectSize
				call drawInitPoint
				retn
initScreen		endp

drawInitPoint	proc near
				pusha
				mov word ptr [currentRow], SCREEN_HEIGHT/2
				mov word ptr [currentCol], SCREEN_WIDTH/2
				call setPointRegs
				call drawUp
				popa
				retn
drawInitPoint	endp


setPointRegs	proc near
				mov al, byte ptr [currentColor]
				xor bh, bh
				mov bl, byte ptr [currentSize]
				inc bl
				mov cx, word ptr [currentCol]
				mov dx, word ptr [currentRow]
				retn
setPointRegs	endp

; -----
; Рисование точки определенного размера в текущей позиции
drawPoint		proc near
				pusha
				call setPointRegs
				cmp ah, UP_ARROW
				je @@moveUp
				cmp ah, DOWN_ARROW
				je @@moveDown
				cmp ah, LEFT_ARROW
				je @@moveLeft
				cmp ah, RIGHT_ARROW
				je @@moveRight
				jmp short @@doneDraw
@@moveUp:		cmp word ptr [currentRow], MIN_ROW
				jbe @@doneDraw
				sub word ptr [currentRow], bx
				call drawUp
				jmp short @@doneDraw
@@moveDown:		cmp word ptr [currentRow], MAX_ROW
				jae @@doneDraw
				add word ptr [currentRow], bx
				call drawDown
				jmp short @@doneDraw
@@moveLeft:		cmp word ptr [currentCol], MIN_COL
				jbe @@doneDraw
				sub word ptr [currentCol], bx
				call drawLeft
				jmp short @@doneDraw
@@moveRight:	cmp word ptr [currentCol], MAX_COL
				jae @@doneDraw
				add word ptr [currentCol], bx
				call drawRight
@@doneDraw:		popa
				retn
drawPoint		endp

; Нарисовать точку (или группу точек) вверх
drawUp			proc near
				push bx cx dx di
				mov di, bx
@@nextUpLn:		push bx dx
@@nextUpDt:		call putDot
				dec dx
				dec bx
				jnz @@nextUpDt
				pop dx bx
				inc cx
				dec di
				jnz @@nextUpLn
				pop di dx cx bx
				retn
drawUp			endp

; Нарисовать точку (или группу точек) вниз
drawDown		proc near
				push bx cx dx di
				mov di, bx
@@nextDownLn:	push bx dx
@@nextDownDt:	call putDot
				inc dx
				dec bx
				jnz @@nextDownDt
				pop dx bx
				inc cx
				dec di
				jnz @@nextDownLn
				pop di dx cx bx
				retn
drawDown		endp

; Нарисовать точку (или группу точек) влево
drawLeft		proc near
				push bx cx dx di
				mov di, bx
@@nextLeftLn:	push bx cx
@@nextLeftDt:	call putDot
				dec cx
				dec bx
				jnz @@nextLeftDt
				pop cx bx
				dec dx
				dec di
				jnz @@nextLeftLn
				pop di dx cx bx
				retn
drawLeft		endp

; Нарисовать точку (или группу точек) вправо
drawRight		proc near
				push bx cx dx di
				mov di, bx
@@nextRightLn:	push bx cx
@@nextRightDt:	call putDot
				inc cx
				dec bx
				jnz @@nextRightDt
				pop cx bx
				dec dx
				dec di
				jnz @@nextRightLn
				pop di dx cx bx
				retn
drawRight		endp

; -----
; Управление выбранным цветом
manageColors	proc near
				push bx
				mov bh, byte ptr [currentColor]
				cmp ah, LEFT_ARROW_CTRL
				jne @@manageClr1
				or bh, bh
				jz @@manageClr1
				dec bh
				call moveSelectColor
				jmp short @@manageClr2
@@manageClr1:	cmp ah, RIGHT_ARROW_CTRL
				jne @@manageClr2
				cmp bh, TOTAL_COLORS
				je @@manageClr2
				inc bh
				call moveSelectColor
@@manageClr2:	pop bx
				retn
manageColors	endp

; -----
; Управление выбранным размером
manageSizes		proc near
				push bx
				mov bh, byte ptr [currentSize]
				cmp ah, UP_ARROW_CTRL
				jne @@manageSize1
				or bh, bh
				jz @@manageSize1
				dec bh
				call moveSelectSize
				jmp short @@manageSize2
@@manageSize1:	cmp ah, DOWN_ARROW_CTRL
				jne @@manageSize2
				cmp bh, TOTAL_SIZES
				je @@manageSize2
				inc bh
				call moveSelectSize
@@manageSize2:	pop bx
				retn
manageSizes		endp

; -----
; Изменить текущий цвет (цвет в BH)
moveSelectColor	proc near
				mov byte ptr [selectedColor], 0Fh;
				call drawSelectColor
				mov byte ptr [selectedColor], 00h;
				mov byte ptr [currentColor], bh
				call drawSelectColor
				retn
moveSelectColor	endp

; -----
; Изменить текущий размер (размер в BH)
moveSelectSize	proc near
				mov byte ptr [selectedSize], 0Fh;
				call drawSelectSize
				mov byte ptr [selectedSize], 00h;
				mov byte ptr [currentSize], bh
				call drawSelectSize
				retn
moveSelectSize	endp

; -----
; Отобразить на экране текущий цвет
drawSelectColor	proc near
				pusha
				mov di, BUTTON_SIZE + BUTTON_GAP
				push di
				xor bh, bh
				mov bl, byte ptr [currentColor]
				mov ax, di
				mul bx
				add ax, HALF_BUTTON_GAP
				push ax
				sub di, HALF_BUTTON_GAP
				mov cx, ax
				mov dx, COLOR_ROW - 3
				call drawHCLine
				pop cx
				pop di
				sub di, HALF_BUTTON_GAP
				mov dx, COLOR_ROW + BUTTON_SIZE + 2
				call drawHCLine
				popa
				retn
drawSelectColor	endp

; -----
; Отобразить на экране текущий размер
drawSelectSize	proc near
				pusha
				mov ax, BUTTON_SIZE + BUTTON_GAP
				xor bh, bh
				mov bl, byte ptr [currentSize]
				mul bx
				add ax, HALF_BUTTON_GAP
				mov dx, ax
				mov cx, SIZE_COL - HALF_BUTTON_GAP
				mov di, BUTTON_SIZE + BUTTON_GAP
				push cx di
				call drawHSLine
				pop di cx
				add dx, BUTTON_SIZE + BUTTON_GAP
				call drawHSLine
				popa
				retn
drawSelectSize	endp

; -----
; Отобразить на экране выбранный цвет
drawHCLine		proc near
				mov al, byte ptr [selectedColor]
				call drawHLine
				retn
drawHCLine		endp

; -----
; Отобразить на экране выбранный размер
drawHSLine		proc near
				mov al, byte ptr [selectedSize]
				call drawHLine
				retn
drawHSLine		endp

; -----
; Отобразить на экране выбранный элемент цвета или размера
drawHLine		proc near
@@drawHDot:		call putDot
				inc cx
				dec di
				jnz @@drawHDot
				retn
drawHLine		endp

; -----
; Нарисовать все кнопки цветов
drawColors		proc near
				pusha
				mov word ptr [colorBtnCol], COLOR_COL	
				mov word ptr [colorBtnRow], COLOR_ROW
				mov cx, TOTAL_COLORS
				xor ax, ax
@@nextColorBtn:	call drawColor
				inc al
				add word ptr [colorBtnCol], BUTTON_SIZE + BUTTON_GAP
				loop @@nextColorBtn
				popa
				retn
drawColors		endp

; -----
; Нарисовать все кнопки размеров
drawSizes		proc near
				pusha
				mov word ptr [sizeBtnCol], SIZE_COL
				mov word ptr [sizeBtnRow], SIZE_ROW
				mov cx, TOTAL_SIZES
				xor ax, ax
@@nextSizeBtn:	call drawSize
				inc al
				add word ptr [sizeBtnRow], BUTTON_SIZE + BUTTON_GAP
				loop @@nextSizeBtn
				call drawSize
				popa
				retn
drawSizes		endp

; -----
; Кнопка выбора цвета, индекс цвета в AL
drawColor		proc near
				pusha
				mov cx, word ptr [colorBtnCol]
				mov bh, BUTTON_SIZE
@@drawNextClrR:	mov bl, BUTTON_SIZE
				mov dx, word ptr [colorBtnRow]
@@drawNextClrD:	call putDot
				inc dx
				dec bl
				jnz @@drawNextClrD
				inc cx
				dec bh
				jnz @@drawNextClrR
				popa
				retn
drawColor		endp

; -----
; Кнопка выбора размера, индекс размера в AL
drawSize		proc near
				pusha
				inc al
				xor ah, ah
				mov cx, word ptr [sizeBtnCol]
				mov dx, word ptr [sizeBtnRow]
				add cx, HALF_BUTTON_SIZE
				add dx, HALF_BUTTON_SIZE
				sub cx, ax
				sub dx, ax
				mov bh, al
@@drawNextSzeR:	push cx
				mov bl, al
@@drawNextSzeD:	call putSizeDot
				inc cx
				dec bl
				jnz @@drawNextSzeD
				pop cx
				inc dx
				dec bh
				jnz @@drawNextSzeR
				popa
@@skipDrawSize:	retn
drawSize		endp

; -----
; Нарисовать точку с координатами DX (строка) и CX (колонка), цвет в AL
putDot			proc near
				push ax bx
				mov ah, 0Ch			; писать графическую точку
				xor bh, bh			; страница 0
				int 10h
				pop bx ax
				retn
putDot			endp

; -----
; Нарисовать точку с координатами DX (строка) и CX (колонка)
putSizeDot		proc near
				push ax bx
				mov ax, 0C00h		; писать графическую точку
				xor bh, bh			; страница 0
				int 10h
				pop bx ax
				retn
putSizeDot		endp

; -----
; Очистить экран (белый фон)
clearScreen		proc near
				pusha
				les di, dword ptr videoMemory
				mov ax, 0FFh 				; Белый цвет
				mov cx, SEG_SIZE			; Размер видеостраицы: 64 kB
				rep stosb 					; Закрасить весь экран в белый цвет
				popa
				retn
clearScreen		endp

; -----
; Получить скан-код клавиши (возвращается в AH)
getKey			proc near
				mov ah, 10h	  				; Ожидание нажатия на любую клавишу
				int 16h
				retn
getKey			endp


; ----------------------
; ----- переменные -----
; ----------------------
even
videoMemory		dw 00h, VGA_SEG		; начальное смещение и адрес сегмента видеопамяти

currentColor	db DEFAULT_COLOR	; текущий выбранный цвет
selectedColor	db 00h				; цвет рамки выбранного цвета

currentSize		db DEFAULT_SIZE		; текущий выбранный цвет
selectedSize	db 00h				; цвет рамки выбранного размера

colorBtnRow		dw ?				; строка кнопки цвета
colorBtnCol		dw ?				; колонка кнопки цвета

sizeBtnRow		dw ?				; строка кнопки размера
sizeBtnCol		dw ?				; колонка кнопки размера

currentRow		dw ? 				; текущая строка курсора
currentCol		dw ?				; текущая колонка курсора

; =================
end start
