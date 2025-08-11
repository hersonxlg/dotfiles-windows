Param(
    [Switch]$delete = $false,
    [ValidateSet("C")]
    [string]$lenguaje = "C",
    [ValidateSet("holamundo", "argumentos","extern_var")]
    [string]$tipo = "holamundo"
)

$tipos = @("holamundo", "argumentos","extern_var")
if($delete){
    $dir = Get-Location
    $dirName = (Split-Path $dir -Leaf )
    if( $tipos -contains $dirName){
        Write-Host " Borando '$dirName' ..." -ForegroundColor Red
        Set-Location ".."
        Remove-Item $dirName
    }
    exit 0;
}

$makefile = @'
# Indica que estamos en Windows
ifeq ($(OS),Windows_NT)
  SHELL := powershell.exe
  .SHELLFLAGS := -NoProfile -Command
endif

CC = gcc
CFLAGS = -Wall -std=c11
SRC = $(wildcard *.c)
OBJ = $(SRC:.c=.o)
EXE = main.exe

all: $(EXE)

$(EXE): $(OBJ)
	$(CC) $(OBJ) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@


run:
	@if(Test-Path $(EXE)){.\$(EXE)}


clean:
	@"$(OBJ)" -split " " | ForEach-Object{ if (Test-Path $$_) { Remove-Item $$_ -Force } }
	@if (Test-Path $(EXE)) { Remove-Item $(EXE) -Force }
'@



$holamundo = @"
#include <stdio.h>

int main(int argc, char** argv){
    printf("hola mundo\n");
    return 0;
}
"@

$argumentos = @"
#include <stdio.h>

int main(int argc, char** argv){
    printf("Cantidad de argumentos: %d\n", argc);
    for(int i=0; i<argc; i++){
        printf("argv[%2d]:%s\n",i, argv[i]);
    }
    return 0;
}
"@

$extern_var1 = @"
#include <stdio.h>

extern char* password;

int main(int argc, char** argv){
    printf("Mi contraseña es: %s\n", password);
    return 0;
}
"@

$extern_var2 = @"
char* password = "ABC1234";
"@

# -------------------------------------------------------------------
# Código:
# -------------------------------------------------------------------
Switch($lenguaje){
    "C" {
        Switch($tipo){
            "holamundo" {
                $data = $holamundo
                (New-Item -ItemType Directory -Name $tipo | Out-Null ) &&
                Set-Location $tipo &&
                $data | Out-File -Encoding  utf8 main.c &&
                $makefile | Out-File -Encoding  utf8 makefile
            }
            "argumentos" {
                $data = $argumentos
                (New-Item -ItemType Directory -Name $tipo | Out-Null ) &&
                Set-Location $tipo &&
                $data | Out-File -Encoding  utf8 main.c &&
                $makefile | Out-File -Encoding  utf8 makefile
            }
            "extern_var" {
                $file1 = $extern_var1
                $file2 = $extern_var2
                (New-Item -ItemType Directory -Name $tipo | Out-Null ) &&
                Set-Location $tipo &&
                $file1 | Out-File -Encoding  utf8 main.c &&
                $file2 | Out-File -Encoding  utf8 PASSWORD.c &&
                $makefile | Out-File -Encoding  utf8 makefile
            }
        }
    }
}



