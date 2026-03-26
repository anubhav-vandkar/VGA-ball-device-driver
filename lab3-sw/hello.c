/*
 * Userspace program that communicates with the vga_ball device driver
 * through ioctls
 *
 * Stephen A. Edwards
 * Columbia University
 */

#include <stdio.h>
#include "vga_ball.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int vga_ball_fd;

/* Read and print the background color */
void print_background_color() {
  vga_ball_arg_t vla;
  
  if (ioctl(vga_ball_fd, VGA_BALL_READ_BACKGROUND, &vla)) {
      perror("ioctl(VGA_BALL_READ_BACKGROUND) failed");
      return;
  }
  printf("%02x %02x %02x\n",
	 vla.background.red, vla.background.green, vla.background.blue);
}

/* Set the background color */
void set_background_color(const vga_ball_color_t *c)
{
  vga_ball_arg_t vla;
  vla.background = *c;
  if (ioctl(vga_ball_fd, VGA_BALL_WRITE_BACKGROUND, &vla)) {
      perror("ioctl(VGA_BALL_SET_BACKGROUND) failed");
      return;
  }
}

void set_ball_position(const vga_ball_pos_t *pos)
{
  vga_ball_pos_t new_pos;
  new_pos = *pos;
  if (ioctl(vga_ball_fd, VGA_BALL_WRITE_POSITION, &new_pos)) {
      perror("ioctl(VGA_BALL_SET_POSITION) failed");
      return;
  }
}

int main()
{
  vga_ball_arg_t vla;
  vga_ball_pos_t pos;

  horizontal_dir h_dir = RIGHT;
  vertical_dir v_dir = DOWN;

  int i;
  static const char filename[] = "/dev/vga_ball";

  static const vga_ball_color_t colors[] = {
    { 0xff, 0x00, 0x00 }, /* Red */
    { 0x00, 0xff, 0x00 }, /* Green */
    { 0x00, 0x00, 0xff }, /* Blue */
    { 0xff, 0xff, 0x00 }, /* Yellow */
    { 0x00, 0xff, 0xff }, /* Cyan */
    { 0xff, 0x00, 0xff }, /* Magenta */
    { 0x80, 0x80, 0x80 }, /* Gray */
    { 0x00, 0x00, 0x00 }, /* Black */
    { 0xff, 0xff, 0xff }  /* White */
  };

 #define COLORS 9

  printf("VGA ball Userspace program started\n");

  if ( (vga_ball_fd = open(filename, O_RDWR)) == -1) {
    fprintf(stderr, "could not open %s\n", filename);
    return -1;
  }

  printf("initial state: ");
  print_background_color();

  // Generate random pos of centre that is confined to the screen with a margin of VGA_BALL_RADIUS
  // boundaries would be X: radius - WIDTH-radius and Y: radius to HEIGHT - radius 
  pos.x = (rand() % (WIDTH - 2*VGA_BALL_RADIUS)) + VGA_BALL_RADIUS;
  pos.y = (rand() % (HEIGHT - 2*VGA_BALL_RADIUS)) + VGA_BALL_RADIUS;
  set_ball_position(&pos);

  int i=0;

  while (1) {
    // set_background_color(&colors[i % COLORS ]);
    // print_background_color();
    // usleep(400000);

    // Move the ball in diagonal directions with bounce off the walls
    pos.x += (h_dir == RIGHT) ? 1 : -1;
    pos.y += (v_dir == DOWN) ? 1 : -1;

    set_ball_position(&pos);

    //when direction changes, change the background color and change direction
    if((pos.x > WIDTH - VGA_BALL_RADIUS) || (pos.x < VGA_BALL_RADIUS)) {
        h_dir = !h_dir;
        set_background_color(&colors[i]);
        i = (i + 1) % COLORS;
    }
    if((pos.y > HEIGHT - VGA_BALL_RADIUS) || (pos.y < VGA_BALL_RADIUS)) {
        v_dir = !v_dir;
        set_background_color(&colors[i % COLORS ]);
        i = (i + 1) % COLORS;
    }

    usleep(10000);
  }
  
  printf("VGA BALL Userspace program terminating\n");
  return 0;
}
