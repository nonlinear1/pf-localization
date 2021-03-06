// https://gcc.gnu.org/wiki/Visibility
#if defined _WIN32 || defined __CYGWIN__
#ifdef BUILDING_DLL
#ifdef __GNUC__
#define DLL_PUBLIC __attribute__ ((dllexport))
#else
#define DLL_PUBLIC __declspec(dllexport) // Note: actually gcc seems to also supports this syntax.
#endif
#else
#ifdef __GNUC__
#define DLL_PUBLIC __attribute__ ((dllimport))
#else
#define DLL_PUBLIC __declspec(dllimport) // Note: actually gcc seems to also supports this syntax.
#endif
#endif
#define DLL_LOCAL
#else
#if __GNUC__ >= 4
#define DLL_PUBLIC __attribute__ ((visibility ("default")))
#define DLL_LOCAL  __attribute__ ((visibility ("hidden")))
#else
#define DLL_PUBLIC
#define DLL_LOCAL
#endif
#endif

/**
* wp is Nx1
* xp is Nx7
* cameraParams is 3x3
* imagePoints is Fx2
* worldPoints is Fx3
*/
typedef struct System {
    double *wp;
    double *xp;
    double *cameraParams;
    double *imagePoints;
    double *worldPoints;
    unsigned int N;
    unsigned int F;
} System;

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

DLL_PUBLIC void updateWeights_cpu(System input);
DLL_PUBLIC void updateWeights_gpu(System input);

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus
