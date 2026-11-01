SECTIONS
{
  . = EV_TEXT;
  .text : { *(.text) }
  . = EV_DATA;
  .data : { *(.data) }
  /DISCARD/ : { *(*) }
}
