/*
 * Copyright 2026, hans2294.
 * Distributed under the terms of the MIT License.
 */
#ifndef LIBELF_MINI_LIBELF_H
#define LIBELF_MINI_LIBELF_H

/*
 * A small, read-only libelf for Mesa on Haiku: the part of the libelf API
 * that Mesa's amd code uses (ac_rtld), for little-endian ELF64 images in
 * memory. Haiku has no libelf; this stands in for elfutils' or Michael
 * Riepe's.
 */

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint64_t Elf64_Addr;
typedef uint64_t Elf64_Off;
typedef uint16_t Elf64_Half;
typedef uint32_t Elf64_Word;
typedef int32_t Elf64_Sword;
typedef uint64_t Elf64_Xword;
typedef int64_t Elf64_Sxword;
typedef uint16_t Elf64_Section;

#define EI_NIDENT	16
#define EI_MAG0		0
#define EI_MAG1		1
#define EI_MAG2		2
#define EI_MAG3		3
#define EI_CLASS	4
#define EI_DATA		5
#define EI_VERSION	6
#define EI_OSABI	7
#define EI_ABIVERSION	8
#define ELFMAG0		0x7f
#define ELFMAG1		'E'
#define ELFMAG2		'L'
#define ELFMAG3		'F'
#define ELFMAG		"\177ELF"
#define SELFMAG		4
#define ELFCLASS64	2
#define ELFDATA2LSB	1

#define EV_NONE		0
#define EV_CURRENT	1

#define ET_NONE		0
#define ET_REL		1
#define ET_EXEC		2
#define ET_DYN		3

typedef struct {
	unsigned char e_ident[EI_NIDENT];
	Elf64_Half e_type;
	Elf64_Half e_machine;
	Elf64_Word e_version;
	Elf64_Addr e_entry;
	Elf64_Off e_phoff;
	Elf64_Off e_shoff;
	Elf64_Word e_flags;
	Elf64_Half e_ehsize;
	Elf64_Half e_phentsize;
	Elf64_Half e_phnum;
	Elf64_Half e_shentsize;
	Elf64_Half e_shnum;
	Elf64_Half e_shstrndx;
} Elf64_Ehdr;

typedef struct {
	Elf64_Word sh_name;
	Elf64_Word sh_type;
	Elf64_Xword sh_flags;
	Elf64_Addr sh_addr;
	Elf64_Off sh_offset;
	Elf64_Xword sh_size;
	Elf64_Word sh_link;
	Elf64_Word sh_info;
	Elf64_Xword sh_addralign;
	Elf64_Xword sh_entsize;
} Elf64_Shdr;

typedef struct {
	Elf64_Word st_name;
	unsigned char st_info;
	unsigned char st_other;
	Elf64_Section st_shndx;
	Elf64_Addr st_value;
	Elf64_Xword st_size;
} Elf64_Sym;

typedef struct {
	Elf64_Addr r_offset;
	Elf64_Xword r_info;
} Elf64_Rel;

typedef struct {
	Elf64_Addr r_offset;
	Elf64_Xword r_info;
	Elf64_Sxword r_addend;
} Elf64_Rela;

typedef struct {
	Elf64_Word n_namesz;
	Elf64_Word n_descsz;
	Elf64_Word n_type;
} Elf64_Nhdr;

#define ELF64_R_SYM(info)	((info) >> 32)
#define ELF64_R_TYPE(info)	((info) & 0xffffffff)
#define ELF64_ST_BIND(info)	((info) >> 4)
#define ELF64_ST_TYPE(info)	((info) & 0xf)

#define STN_UNDEF	0
#define SHN_UNDEF	0
#define SHN_XINDEX	0xffff

#define SHT_NULL		0
#define SHT_PROGBITS	1
#define SHT_SYMTAB		2
#define SHT_STRTAB		3
#define SHT_RELA		4
#define SHT_NOTE		7
#define SHT_NOBITS		8
#define SHT_REL			9

#define SHF_WRITE		0x1
#define SHF_ALLOC		0x2
#define SHF_EXECINSTR	0x4

#define STB_LOCAL	0
#define STB_GLOBAL	1
#define STT_NOTYPE	0
#define STT_OBJECT	1
#define STT_FUNC	2
#define STT_SECTION	3

typedef enum {
	ELF_T_BYTE = 0,
} Elf_Type;

typedef struct {
	void *d_buf;
	Elf_Type d_type;
	unsigned int d_version;
	size_t d_size;
	int64_t d_off;
	size_t d_align;
} Elf_Data;

typedef struct Elf Elf;
typedef struct Elf_Scn Elf_Scn;

unsigned int elf_version(unsigned int version);
Elf *elf_memory(char *image, size_t size);
int elf_end(Elf *elf);
int elf_errno(void);
const char *elf_errmsg(int error);

Elf64_Ehdr *elf64_getehdr(Elf *elf);
int elf_getshdrnum(Elf *elf, size_t *count);
int elf_getshdrstrndx(Elf *elf, size_t *index);
Elf_Scn *elf_getscn(Elf *elf, size_t index);
Elf_Scn *elf_nextscn(Elf *elf, Elf_Scn *scn);
size_t elf_ndxscn(Elf_Scn *scn);
Elf64_Shdr *elf64_getshdr(Elf_Scn *scn);
Elf_Data *elf_getdata(Elf_Scn *scn, Elf_Data *data);
char *elf_strptr(Elf *elf, size_t section, size_t offset);

#ifdef __cplusplus
}
#endif

#endif
