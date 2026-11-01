/*
 * Copyright 2026, hans2294.
 * Distributed under the terms of the MIT License.
 */

/*	Read-only libelf for little-endian ELF64 images in memory; see libelf.h. */

#include "libelf.h"

#include <stdlib.h>
#include <string.h>

struct Elf_Scn {
	Elf *elf;
	size_t index;
	Elf64_Shdr *shdr;
	Elf_Data data;
};

struct Elf {
	char *image;
	size_t size;
	Elf64_Ehdr *ehdr;
	size_t section_count;
	size_t section_names;
	Elf_Scn *sections;
};

enum {
	ERROR_NONE,
	ERROR_VERSION,
	ERROR_MEMORY,
	ERROR_FORMAT,
	ERROR_RANGE,
};

static __thread int sError;

static const char *const kErrors[] = {
	"no error",
	"unknown ELF version",
	"out of memory",
	"not a little-endian ELF64 image",
	"out of range",
};


static void *
fail(int error)
{
	sError = error;
	return NULL;
}


unsigned int
elf_version(unsigned int version)
{
	if (version != EV_NONE && version != EV_CURRENT) {
		sError = ERROR_VERSION;
		return EV_NONE;
	}
	return EV_CURRENT;
}


int
elf_errno(void)
{
	int error = sError;
	sError = ERROR_NONE;
	return error;
}


const char *
elf_errmsg(int error)
{
	if (error == -1)
		error = sError;
	if (error < 0 || error >= (int)(sizeof(kErrors) / sizeof(kErrors[0])))
		return "unknown error";
	return error == ERROR_NONE ? NULL : kErrors[error];
}


static int
in_image(const Elf *elf, uint64_t offset, uint64_t size)
{
	return offset <= elf->size && size <= elf->size - offset;
}


Elf *
elf_memory(char *image, size_t size)
{
	Elf64_Ehdr *ehdr = (Elf64_Ehdr *)image;
	if (image == NULL || size < sizeof(Elf64_Ehdr)
		|| memcmp(ehdr->e_ident, ELFMAG, SELFMAG) != 0
		|| ehdr->e_ident[EI_CLASS] != ELFCLASS64
		|| ehdr->e_ident[EI_DATA] != ELFDATA2LSB)
		return fail(ERROR_FORMAT);

	Elf *elf = calloc(1, sizeof(Elf));
	if (elf == NULL)
		return fail(ERROR_MEMORY);
	elf->image = image;
	elf->size = size;
	elf->ehdr = ehdr;

	if (ehdr->e_shoff != 0) {
		if (ehdr->e_shentsize != sizeof(Elf64_Shdr)
			|| !in_image(elf, ehdr->e_shoff, sizeof(Elf64_Shdr))) {
			free(elf);
			return fail(ERROR_FORMAT);
		}
		Elf64_Shdr *headers = (Elf64_Shdr *)(image + ehdr->e_shoff);
		// past 0xff00 sections the real numbers live in section 0
		size_t count = ehdr->e_shnum != 0 ? ehdr->e_shnum : headers[0].sh_size;
		size_t names = ehdr->e_shstrndx != SHN_XINDEX ? ehdr->e_shstrndx
			: headers[0].sh_link;
		if (!in_image(elf, ehdr->e_shoff, count * sizeof(Elf64_Shdr))) {
			free(elf);
			return fail(ERROR_FORMAT);
		}
		elf->sections = calloc(count, sizeof(Elf_Scn));
		if (elf->sections == NULL) {
			free(elf);
			return fail(ERROR_MEMORY);
		}
		for (size_t i = 0; i < count; i++) {
			elf->sections[i].elf = elf;
			elf->sections[i].index = i;
			elf->sections[i].shdr = &headers[i];
		}
		elf->section_count = count;
		elf->section_names = names;
	}
	return elf;
}


int
elf_end(Elf *elf)
{
	if (elf != NULL) {
		free(elf->sections);
		free(elf);
	}
	return 0;
}


Elf64_Ehdr *
elf64_getehdr(Elf *elf)
{
	return elf != NULL ? elf->ehdr : NULL;
}


int
elf_getshdrnum(Elf *elf, size_t *count)
{
	if (elf == NULL)
		return -1;
	*count = elf->section_count;
	return 0;
}


int
elf_getshdrstrndx(Elf *elf, size_t *index)
{
	if (elf == NULL)
		return -1;
	*index = elf->section_names;
	return 0;
}


Elf_Scn *
elf_getscn(Elf *elf, size_t index)
{
	if (elf == NULL || index >= elf->section_count)
		return fail(ERROR_RANGE);
	return &elf->sections[index];
}


Elf_Scn *
elf_nextscn(Elf *elf, Elf_Scn *scn)
{
	size_t next = scn != NULL ? scn->index + 1 : 1;
	if (elf == NULL || next >= elf->section_count)
		return NULL;
	return &elf->sections[next];
}


size_t
elf_ndxscn(Elf_Scn *scn)
{
	return scn != NULL ? scn->index : SHN_UNDEF;
}


Elf64_Shdr *
elf64_getshdr(Elf_Scn *scn)
{
	return scn != NULL ? scn->shdr : NULL;
}


/*!	A section's contents as one Elf_Data; there is never a second. */
Elf_Data *
elf_getdata(Elf_Scn *scn, Elf_Data *data)
{
	if (scn == NULL || data != NULL)
		return NULL;
	Elf64_Shdr *shdr = scn->shdr;
	Elf *elf = scn->elf;
	if (shdr->sh_type != SHT_NOBITS
		&& !in_image(elf, shdr->sh_offset, shdr->sh_size))
		return fail(ERROR_RANGE);

	scn->data.d_buf = shdr->sh_type == SHT_NOBITS ? NULL
		: elf->image + shdr->sh_offset;
	scn->data.d_type = ELF_T_BYTE;
	scn->data.d_version = EV_CURRENT;
	scn->data.d_size = shdr->sh_size;
	scn->data.d_off = 0;
	scn->data.d_align = shdr->sh_addralign;
	return &scn->data;
}


char *
elf_strptr(Elf *elf, size_t section, size_t offset)
{
	Elf_Scn *scn = elf_getscn(elf, section);
	if (scn == NULL)
		return NULL;
	Elf64_Shdr *shdr = scn->shdr;
	if (shdr->sh_type != SHT_STRTAB || offset >= shdr->sh_size
		|| !in_image(elf, shdr->sh_offset, shdr->sh_size))
		return fail(ERROR_RANGE);
	char *string = elf->image + shdr->sh_offset + offset;
	// the string must end inside the section
	if (memchr(string, '\0', shdr->sh_size - offset) == NULL)
		return fail(ERROR_RANGE);
	return string;
}
