# Animal Images for Shot Placement

## Adding Real Animal Images

To replace the placeholder images with real animal photos:

1. Add your animal silhouette/profile images to this directory (`public/images/animals/`)
2. Name your files to match the animal IDs in the application:
   - `deer.png` - Whitetail/Mule deer profile
   - `elk.png` - Elk profile image 
   - `bear.png` - Bear profile image
   - `boar.png` - Wild boar/hog profile
   - `moose.png` - Moose profile image
   - `turkey.png` - Turkey profile image
   - `coyote.png` - Coyote profile image
   - `rabbit.png` - Rabbit profile image

## Image Requirements

For best results:
- Use **broadside (side view)** profile images
- Use PNG images with transparent backgrounds if possible
- Recommended size: at least 600×400 pixels 
- Images should be properly licensed for use (use public domain or purchased stock photos)

## Adjusting Vital Zone Placement

If you add your own images and need to adjust the vital zone positions:

1. Open `src/components/ballistics/HuntingShotPlacement.tsx`
2. Find the `animalData` object
3. Adjust the `x` and `y` coordinates for each vital zone and recommended shot
4. Values are based on a 300×200 SVG coordinate system

## Example Sources for Images

Here are some potential sources for properly licensed animal silhouette images:
- Public domain wildlife illustrations
- Wildlife management agency publications (with permission)
- Stock photo sites with appropriate licensing
- Self-created illustrations

Remember to respect copyright and obtain proper permissions when using images. 