/* aicswitch: flip AIC8800 WiFi/BT dongles out of their "driver CD" mode.
 * The vendor CDB (FD 00..00 F2) comes from the Windows Usb_Driver.dll the
 * dongle ships with; it is sent through the Linux SCSI generic (SG_IO) API. */
#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <scsi/sg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#ifndef VERSION
#define VERSION "dev"
#endif

/* USB IDs that expose the fake disk and accept the switch command. */
static const char *ids[] = { "1111:1111", NULL };

static int read_id(const char *dir, const char *name, char *out)
{
	char path[PATH_MAX + 16];
	snprintf(path, sizeof path, "%s/%s", dir, name);
	FILE *f = fopen(path, "r");
	int ok = f && fscanf(f, "%4s", out) == 1;
	if (f)
		fclose(f);
	return ok;
}

/* Walk up from the sg device in sysfs to its USB device and match its ID. */
static int is_aic(const char *sg)
{
	char path[PATH_MAX], vid[5], pid[5], id[10];
	snprintf(path, sizeof path, "/sys/class/scsi_generic/%s/device", sg);
	char *dir = realpath(path, NULL);
	int hit = 0;

	for (char *s; dir && !hit && (s = strrchr(dir, '/')) && s != dir; *s = 0)
		if (read_id(dir, "idVendor", vid) && read_id(dir, "idProduct", pid)) {
			snprintf(id, sizeof id, "%s:%s", vid, pid);
			for (const char **p = ids; *p; p++)
				hit |= !strcmp(*p, id);
			break;
		}
	free(dir);
	return hit;
}

static int switch_dev(const char *dev)
{
	unsigned char cdb[16] = { [0] = 0xfd, [15] = 0xf2 }; /* AIC "switch mode" */
	unsigned char sense[32];
	sg_io_hdr_t io = { .interface_id = 'S', .dxfer_direction = SG_DXFER_NONE,
			   .cmd_len = sizeof cdb, .cmdp = cdb, .mx_sb_len = sizeof sense,
			   .sbp = sense, .timeout = 5000 };
	int fd = open(dev, O_RDWR | O_NONBLOCK);

	if (fd < 0 || ioctl(fd, SG_IO, &io) < 0) {
		perror(dev);
		if (fd >= 0)
			close(fd);
		return 1;
	}
	close(fd);
	printf("aicswitch: %s switched to WiFi mode\n", dev);
	return 0;
}

int main(int argc, char **argv)
{
	if (argc > 1 && (!strcmp(argv[1], "-v") || !strcmp(argv[1], "--version")))
		return puts("aicswitch " VERSION) < 0;
	if (argc > 1 && argv[1][0] == '-') {
		fprintf(stderr, "usage: aicswitch [/dev/sgN]\n");
		return argv[1][1] != 'h';
	}
	if (argc > 1)
		return switch_dev(argv[1]);

	DIR *d = opendir("/sys/class/scsi_generic");
	struct dirent *e;
	char dev[300];
	int found = 0, rc = 0;

	while (d && (e = readdir(d)))
		if (e->d_name[0] != '.' && is_aic(e->d_name)) {
			snprintf(dev, sizeof dev, "/dev/%s", e->d_name);
			rc |= switch_dev(dev);
			found = 1;
		}
	if (d)
		closedir(d);
	if (!found)
		fprintf(stderr, "aicswitch: no AIC dongle in storage mode found\n");
	return found ? rc : 1;
}
