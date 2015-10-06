#sketchup-loop-subdivision
A  Loop subdivision plugin for Google Sketchup. Loop subdivision smooths hard edges to give a more rounded organic looking shape. 
![A wine glass model in Sketchup smoothed using this plugin](http://www.guitar-list.com/sites/default/files/styles/article-pic/public/gearpics/Smooth-glass.jpg)

##Installing
Download the file loop_subdiv.rb from http://www.guitar-list.com/download-software/sketchup-loop-subdivision-smooth-plugin and save it in your Google Sketchup plugins directory. 
    On Windows it will be somewhere like C:\Program Files\Google\Google Sketchup 7\Plugins.
    On Mac OSX. The sketchup plugins folder is /Library/Application Support/Google SketchUp 7/SketchUp/Plugins
Re-start Sketchup, there should now be an extra option "Loop subdivide smooth" in the tools menu
    
##Using
To use the plugin select your model and click "Loop subdivide smooth" in the tools menu. A box will appear asking how many times you want to repeat the subdivision (1,2,3 or 4 times). More repeats gives a smoother model, but also takes longer, so try 1 or 2 first.

You can choose whether the subdivided object has softened and smoothed edges. If you have a large model (with lots of faces) the smoothing will take a long time so be prepared to wait!

The smoothed model is added to a new layer(called Loop_subdiv_XXXX). The original selection is deleted (but you can Undo the operation to get it back)

##Technical details
For the technical details see the Hoppes and co-workers paper: Piecewise Smooth Surface Reconstruction . This paper also describes how to do partial subdivision, using crease edges and darts, which are not yet implemented in this plugin.

##Known issues
There are known issues with non-manifold meshes where adjacent faces do not share edges (try smoothing a capital E), I am looking for solutions. Also when smoothing components the face materials are lost in the smoothed object.

