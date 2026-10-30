/* a kernel's devices, each a table of functions (Plan 9's Dev) */
typedef struct Dev Dev;
struct Dev {
	char	*name;
	int	(*read)(char*, int);
	int	(*write)(char*, int);
};

extern Dev consdev;
extern Dev nulldev;
extern Dev *devtab[];
