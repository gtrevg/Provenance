#include <stdio.h>
#include <stddef.h>

#include "../pico/pico_int.h"

#define DUMP(f, prefix, type, field) \
  fprintf(f, "#define %-20s 0x%02x\n", \
    prefix #field, (int)offsetof(type, field))

#define DUMP_P(f, field) \
  fprintf(f, "#define %-20s 0x%04x\n", \
    "OFS_Pico_" #field, (char *)&p.field - (char *)&p)

#define DUMP_PS(f, s1, field) \
  fprintf(f, "#define %-20s 0x%04x\n", \
    "OFS_Pico_" #s1 "_" #field, (char *)&p.s1.field - (char *)&p)

#define DUMP_EST(f, field) \
	DUMP(f, "OFS_EST_", struct PicoEState, field)

#define DUMP_PMEM(f, field) \
	DUMP(f, "OFS_PMEM_", struct PicoMem, field)

extern struct Pico p;

int main(int argc, char *argv[])
{
  char buf[128];
  FILE *f;

  snprintf(buf, sizeof(buf), "pico/pico_int_o%d.h", sizeof(void *) * 8);
  f = fopen(buf, "w");
  if (!f) {
    perror("fopen");
    return 1;
  }

  fprintf(f, "/* autogenerated by %s, do not edit */\n", argv[0]);
  DUMP_PS(f, video, reg);
  DUMP_PS(f, m, rotate);
  DUMP_PS(f, m, z80Run);
  DUMP_PS(f, m, dirtyPal);
  DUMP_PS(f, m, hardware);
  DUMP_PS(f, m, z80_reset);
  DUMP_PS(f, m, sram_reg);
  DUMP_P (f, sv);
  DUMP_PS(f, sv, data);
  DUMP_PS(f, sv, start);
  DUMP_PS(f, sv, end);
  DUMP_PS(f, sv, flags);
  DUMP_P (f, rom);
  DUMP_P (f, romsize);
  DUMP_EST(f, DrawScanline);
  DUMP_EST(f, rendstatus);
  DUMP_EST(f, DrawLineDest);
  DUMP_EST(f, HighCol);
  DUMP_EST(f, HighPreSpr);
  DUMP_EST(f, Pico);
  DUMP_EST(f, PicoMem_vram);
  DUMP_EST(f, PicoMem_cram);
  DUMP_EST(f, PicoOpt);
  DUMP_EST(f, Draw2FB);
  DUMP_EST(f, HighPal);
  DUMP_PMEM(f, vram);
  DUMP_PMEM(f, vsram);
  fclose(f);

  return 0;
}
