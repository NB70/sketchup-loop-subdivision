# Loop subdivision smoothing using the algorithm of Charles Loop
# Author Nathan B (www.guitar-list.com). Last edited 23 June 2009
# Use this script for good only
# Place script in your Sketchup Plugins directory
# To use: select your model and choose "Loop subdivision smooth" in the Tools Menu
# Apache 2.0 license

require 'sketchup.rb'

class Sketchup::Face

   def loop_centroid
      pts=[]
      self.outer_loop.vertices.each do |v|
         pts.push v.position
      end
      loop_subdiv_average_points(pts).project_to_plane(self.plane)
   end

   def loop_simple_convex_nontriangle
      ((self.loops.length==1)&&(self.edges.length>3)&&(self.outer_loop.convex?))
   end

   def loop_triangulate(tform)
      if (self.loop_simple_convex_nontriangle)
         self.loop_triangulate_convex(tform)
      else
         self.loop_triangulate_nonconvex(tform)
      end
   end

   def loop_triangulate_convex(tform)
      cent = self.loop_centroid.transform!(tform)
      face_array=[]
      self.outer_loop.edges.each do |edge|
         pts=[]
         pts.push edge.start.position.transform!(tform)
         pts.push edge.end.position.transform!(tform)
         pts.push cent
         face_array.push pts
      end
      face_array
   end

   def loop_triangulate_nonconvex(tform)
      face_array=[]
      mesh = self.mesh 0
      mesh.transform! tform
      for i in 1..mesh.count_polygons do
         pts=[]
         pts=mesh.polygon_points_at(i)
         unless(loop_subdiv_colinear?(pts))
            face_array.push pts
            #else
            #  print"Non-manifold\n"
         end
      end
      face_array
   end
end

class Sketchup::Edge

   def loop_subdiv_point
      pts=[]
      weights=[]
      point=nil
      self.faces.each do |face|
         #if (face.layer==$oldlayer)
         face.vertices.each do |vertex|
            if(!self.used_by? vertex)
               pts.push vertex.position
            end
         end
         #end
      end
      point = Geom::Point3d.linear_combination 0.5, self.start.position, 0.5, self.end.position
      if (pts.length>1)  #not the boundary case
         p1 = Geom::Point3d.linear_combination 0.5, pts[0], 0.5, pts[1]
         point = Geom::Point3d.linear_combination 0.25, p1, 0.75, point
      end
      @subdivpoint=point
   end

   def getlooppoint
      if (@subdivpoint.nil?)
         self.loop_subdiv_point
      end
      @subdivpoint
   end

end

class Sketchup::Vertex

   def loop_subdiv_point
      n=0; b=0; pts=[]; point=nil
      n=self.edges.length
      if (n>3)
         b=3.0/(8.0*n)
      elsif(n==3)
         b=0.1875
      elsif(n==2) #boundary case
         b=0.25
      end
      if (n>1)
         self.edges.each do |edge|
            v = edge.other_vertex self
            pts.push(v.position)
         end
         point = loop_subdiv_average_points(pts)
         point = Geom::Point3d.linear_combination( n*b, point, 1-(n*b), self.position)
      end
      point
   end

end

def loop_subdiv_colinear?(pts)
   #check if the three points lie on the same line
   return if (pts.length<3)
   pts[0].on_line?(pts[1],pts[2])
end

def loop_subdiv_average_points(pts)
   x=0;y=0;z=0
   pts.each do |pt|
      x+=pt.x
      y+=pt.y
      z+=pt.z
   end
   Geom::Point3d.new(x/pts.length,y/pts.length,z/pts.length)
end

def loop_subdiv_erase_mesh(layer)
   #erase all elements on the layer
   model = Sketchup.active_model
   ent_arr=[]
   model.entities.each do |element|
      if((element.layer==layer))
         ent_arr.push element
      end
   end
   ent_arr.each {|e| e.erase! if not e.deleted?}
end

def loop_subdiv_find_faces( others, entity_array, entities, tform)
   #find all faces in the selection, exploding groups and components
   entities.each do |entity|
      if( entity.typename == "Group")
         others = loop_subdiv_find_faces(others, entity_array, entity.entities, tform * entity.transformation)
      elsif( entity.typename == "ComponentInstance")
         others = loop_subdiv_find_faces(others, entity_array, entity.definition.entities, tform * entity.transformation)
      elsif ( entity.typename == "Face")
         entity_array.push [entity,tform,entity.material,entity.back_material]
      else
         others = others + 1
      end
   end
   others
end

def loop_getvertices(sel,faces_array)
   vertices=[]
   $all_verts=[]
   sel.each do |ent|
      if ent.class==Sketchup::Face
         pts=[]
         ent.edges.each do |edge|
            vertices.push(edge.vertices)
            pts.push(edge.getlooppoint)
         end
         faces_array.push [pts, ent.material, ent.back_material]
      end
   end
   vertices.flatten!
   vertices.uniq!
   $all_verts=vertices
end

def loop_vertices_calculate(faces_array)
   $all_verts.each do |v|
      v1 = v.loop_subdiv_point
      v.faces.each do |face|
         pts=[v1]
         face.edges.each do |edge|
            if (v.used_by? edge)
               pts.push edge.getlooppoint
            end
            faces_array.push [pts, face.material, face.back_material]
         end
      end
   end
   #print 'New model has '+$all_verts.length.to_s+' vertices and '+faces_array.length.to_s+'faces '+"\n"
end

def loop_subdivide(ents, repeats=1,soften=true)
   if (ents.length > 0)
      #start=Time.new
      model = Sketchup.active_model
      original_layer =  model.active_layer
      #find faces
      faces_array=[]
      others = loop_subdiv_find_faces(0, faces_array, ents, Geom::Transformation.new())
      loop_layer_name = "Loop_subdiv-"+rand(10000000).to_s+"-"
      model.active_layer = model.layers.add(loop_layer_name)
      entities = model.entities
      $oldlayer = model.active_layer
      #triangulate each face
      new_faces_array =[]
      $problem_faces = []
      $sel = model.selection
      $sel.clear
      delete_edges = []
      faces_array.each do |faceTform|
         face = faceTform[0]
         tform = faceTform[1]
         new_faces = []
         faces = []
         faces = face.loop_triangulate(tform)
         face.edges.each {|e| e.layer=$oldlayer}
         face.erase!
         faces.each do |pts|
            face = entities.add_face(pts)
            face.material = faceTform[2]
            face.back_material = faceTform[3]
            new_faces_array.push face
         end
      end
      #Loop subdivide
      for i in (1..repeats)
         faces_array=[]
         loop_getvertices(new_faces_array,faces_array)
         loop_vertices_calculate(faces_array)
         newlayer=model.layers.add(loop_layer_name+i.to_s)
         model.active_layer = (newlayer)
         loop_subdiv_erase_mesh($oldlayer)
         new_faces_array = []
         #Add the subdivision faces to the model
         faces_array.each do |facedata|
            face = entities.add_face(facedata[0])
            face.material = facedata[1]
            face.back_material = facedata[2]
            if (soften==true)
               face.edges.each do |edge|
                  edge.soft=true
                  edge.smooth=true
               end
            end
            new_faces_array.push(face)
         end
         $oldlayer=newlayer
      end
      model.layers.purge_unused
      model.active_layer = original_layer
      #print "calculated subdivision in #{Time.new-start} seconds"
   end
end

def loop_subdiv_mesh
   model = Sketchup.active_model
   ss = model.selection
   if (Sketchup.version_number==7)
      model.start_operation("loop subdivision",true)
   else
      model.start_operation("loop subdivision")
   end
   if ss.empty?
      answer = UI.messagebox("No objects selected. Subdivide entire model?", MB_YESNOCANCEL)
      if( answer == 6 )
         divide_ents = model.entities
      else
         divide_ents = ss
      end
   else
      divide_ents = ss
   end
   option_result = loop_subdiv_options_dialog
   subdiv_count = option_result[0].to_i
   soften = (option_result[1]=="yes")
   loop_subdivide(divide_ents,subdiv_count,soften)
   model.commit_operation
end

def loop_subdiv_options_dialog
   options_list=["1","2","3","4"].join("|")
   prompts=["How many times?","Soften and smooth edges?"]
   enums=[options_list,"yes|no"]
   values=["1","yes"]
   results = inputbox prompts, values, enums, "Repeat subdivision ?"
   return if not results
   results
end

if( not file_loaded?("loop_subdiv.rb") )
   add_separator_to_menu("Tools")
   UI.menu("Tools").add_item("Loop subdivision smooth") { loop_subdiv_mesh }
end

file_loaded("loop_subdiv.rb")
