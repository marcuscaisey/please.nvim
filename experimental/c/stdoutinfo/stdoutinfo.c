#include <err.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <util.h>

int main() {
  struct winsize win;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &win) == -1) {
    err(1, "ioctl");
  }
  printf("Rows: %d, Cols: %d\n", win.ws_row, win.ws_col);

  struct termios term;
  if (ioctl(STDOUT_FILENO, TIOCGETA, &term) == -1) {
    err(2, "ioctl");
  }
  printf("Input flags: %lu, Output flags: %lu\n", term.c_iflag, term.c_oflag);

  char *tty;
  if ((tty = ttyname(STDOUT_FILENO)) == NULL) {
    err(3, "ttyname");
  }
  printf("tty: %s\n", tty);

  return 0;
}
