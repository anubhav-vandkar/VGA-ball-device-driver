#ifndef _VGA_BALL_H
#define _VGA_BALL_H

#include <linux/ioctl.h>

typedef struct {
  unsigned char red, green, blue;
} vga_ball_color_t;
  
typedef struct {
  unsigned short x;
  unsigned short y; 
} vga_ball_pos_t;

typedef enum { LEFT, RIGHT } horizontal_dir;
typedef enum { UP, DOWN } vertical_dir;

typedef struct {
  vga_ball_color_t background;
} vga_ball_arg_t;

#define VGA_BALL_MAGIC 'q'

#define WIDTH 640
#define HEIGHT 480

#define VGA_BALL_RADIUS 32

/* ioctls and their arguments */
#define VGA_BALL_WRITE_BACKGROUND _IOW(VGA_BALL_MAGIC, 1, vga_ball_arg_t)
#define VGA_BALL_READ_BACKGROUND  _IOR(VGA_BALL_MAGIC, 2, vga_ball_arg_t)
//new ioctl
#define VGA_BALL_WRITE_POSITION _IOW(VGA_BALL_MAGIC, 3, vga_ball_pos_t)

#endif
