(* Psnr says how close a lossy picture is to the one it was made from,
 * in decibels. It is the video field's common ruler.

   It computes the **mean squared error** of the pixels' channels (red,
   green and blue; alpha isn't compared), and from it the **peak
   signal-to-noise ratio**: the largest value squared over that error,
   on a logarithmic scale:

     PSNR = 10 log10 (255^2 / MSE)

   Here is a worked example. When every channel is off by 2, the MSE is
   4 and the PSNR is 42.1 dB; when it is off by 16, the PSNR is
   24.0 dB. Around 30 dB a picture is watchable, and past 40 it looks
   the same. Two identical pictures are infinitely far from noise. It
   is not how the eye judges: a slight shift everywhere scores worse
   than one blotch that the eye catches at once. Newer measures try to
   judge as the eye does (SSIM, 2004; VMAF, 2016). *)

(* [mse a b] is the mean squared error of two pictures of the same
 * size *)
val mse : Rgba_image.t -> Rgba_image.t -> float

(* [of_mse e] is the PSNR in dB, and [infinity] for 0 *)
val of_mse : float -> float

(* [psnr a b] = of_mse (mse a b) *)
val psnr : Rgba_image.t -> Rgba_image.t -> float
