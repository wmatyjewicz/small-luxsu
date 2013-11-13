# SmallLuxSU - SmallLuxGPU exporter for SketchUp
#
# Copyright (C) 2013 Wojciech Matyjewicz <wmatyjewicz[at]fastmail[dot]fm>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Linking SmallLuxSU statically or dynamically with other modules is
# making a combined work based on SmallLuxSU. Thus, the terms and conditions
# of the GNU General Public License cover the whole combination.
# 
# In addition, as a special exception, the copyright holders of SmallLuxSU
# give you permission to combine SmallLuxSU program with free software
# programs or libraries that are released under the GNU LGPL and with code
# included in the standard release of SketchUp, SketchUp Make or SketchUp Pro
# under, respectively, the SketchUp, Sketchup Make or SketchUp Pro license
# (or modified versions of such code, with unchanged license). You may copy
# and distribute such a system following the terms of the GNU GPL for
# SmallLuxSU and the licenses of the other code concerned, provided that
# you include the source code of that other code when and as the GNU GPL
# requires distribution of source code.
#
# Note that people who make modified versions of SmallLuxSU are not obligated
# to grant this special exception for their modified versions; it is their
# choice whether to do so. The GNU General Public License gives permission
# to release a modified version without this exception; this exception also
# makes it possible to release a modified version which carries forward this
# exception. 

require 'sketchup.rb'

module SmallLuxSU

  # TODO: prototype
  class SmallLuxSUError < StandardError
  end

  # TODO: prototype, check how own exception should look like in Ruby
  class TextureWriterError < SmallLuxSUError
    def initialize(external_material, msg)
      @msg = msg
      @external_material = external_material
    end

    def to_s
      "Material #{@external_material.sketchup_name}: #{@msg}"
    end
  end

  # Material for external use (outside of SketchUp).
  #
  # Instances of this class represent materials from the perspective of an
  # external program.
  #
  # Not every SketchUp material can be translated to a single material of an
  # external program (see comments for +TexturedExternalMaterial+). In such a
  # case the SketchUp material is translated to multiple external materials.
  class ExternalMaterial
    # Returns true if the material requires 3-D objects to be UV mapped on
    # this material.
    def requires_uv_mapping?
      # By default, it does not.
      false
    end
  end

  # Default material for external use (outside of SketchUp).
  #
  # The default SketchUp material is always translated to one external material.
  class DefaultExternalMaterial < ExternalMaterial
    def name
      'default'
    end
  end

  # Material for external use (outside of SketchUp) that represents some
  # non-default SketchUp material.
  class RealExternalMaterial < ExternalMaterial
    # TODO: attr_reader necessary?
    # SketchUp material this external material represents.
    attr_reader :sketchup_material

    def initialize(sketchup_material)
      @sketchup_material = sketchup_material
    end

    def sketchup_name
      @sketchup_material.display_name
    end

    def name
      # By default, the name of the external material is the same as
      # the name of SketchUp material it represents.
      sketchup_name
    end
  end

  # Solid (colored, not textured) material for external use (outside of
  # SketchUp).
  #
  # A solid SketchUp material is always translated to one external material.
  class SolidExternalMaterial < RealExternalMaterial
  end

  # Textured (not colored) material for external use (outside of SketchUp).
  #
  # SketchUp allows to position texture on a face using three coordinates (UVQ)
  # while most other programs use only two (UV). If a texture is positioned on
  # some face with a non-affine transformation (using the third coordinate Q,
  # that is distorting the texture, that is using the yellow pin in SketchUp)
  # then an external material specific to this particular face is generated:
  # such an external material uses pretransformed texture that can be positioned
  # in the same way as the original one but using affine transformation (only UV
  # coordinates). Hence, multiple external materials may exist for a single
  # SketchUp material if the texture of the SketchUp material is positioned
  # using various non-affine transformations.
  #
  # More info: http://sketchucation.com/forums/viewtopic.php?f=180&t=47123
  class TexturedExternalMaterial < RealExternalMaterial
    # TODO: attr_reader necessary?
    # A sample face with this external material.
    attr_reader :sample_face

    def initialize(sketchup_material, sample_face)
      super(sketchup_material)
      @sample_face = sample_face
    end

    # OVERRIDE
    def requires_uv_mapping?
      true
    end

    # OVERRIDE
    def name
      # TODO: use simpler identifier than @sample_face.to_s
      "#{sketchup_name}-#{@sample_face}#"
    end

    def file_name_extension
      extension = File.extname(@sketchup_material.texture.filename)
      if extension.empty?
        '.tex'
      else
        extension
      end
    end

    FILE_WRITE_OK = 0
    FILE_WRITE_FAILED_INVALID_TIFF = 1

    # TODO: comment, prototype
    def write_texture(file_name, part_builder)
      result = part_builder.texture_writer.write(@sample_face, true, file_name)
      if result == FILE_WRITE_OK
        return file_name
      elsif result == FILE_WRITE_FAILED_INVALID_TIFF
        raise TextureWriterError.new(self, 'Invalid TIFF')
      else
        raise TextureWriterError.new(self, 'Unknown')
      end
    end
  end

  # A 3-D mesh consisting of triangles.
  #
  # The mesh is represented as a set of vertices and a set of triangles.  The
  # triangles are represented as triplets of vertex indices. Indexing starts
  # from 0. Vertex is characterized by position and normal vector.
  #
  # TODO: check and add comment about triangle orientation
  class TriangleMesh
    def initialize
      # An array of vertices positions as Point3d objects.
      @vertices_positions = []

      # An array of vertices normals as Vector3d objects: i-th normal is for
      # i-th vertex.
      @vertices_normals = [] 
      
      # An array of triplets of vertex indices.
      @triangles = []
    end

    # Adds a vertex. The vertex will receive an index equal to the number of
    # vertices belonging to the mesh so far (not counting this one).
    def add_vertex(position, normal)
      @vertices_positions << position
      @vertices_normals << normal
    end

    def add_triangle(triangle)
      @triangles << triangle
    end

    def vertex_count
      @vertices_positions.length
    end

    def triangle_count
      @triangles.length
    end

    # Iterates over vertices. It takes a block with two parameters: position and
    # normal.
    def each_vertex
      i = 0
      @vertices_positions.each { |position|
        normal = @vertices_normals[i]
        yield position, normal
        i += 1
      }
    end

    # Iterates over triangles. It takes a block with one parameter: triangle
    # triplet.
    def each_triangle(&block)
      @triangles.each(&block)
    end
  end

  # A 3-D mesh consisting of triangles that is UV mapped to some material.
  #
  # It is an extension of +TriangleMesh+ with UV coordinates for each vertex.
  class UVMappedTriangleMesh < TriangleMesh
    def initialize
      super

      # An array of vertices UV coordinates as Point3d objects (x=u, x=v, z is
      # ignored)
      @vertices_uvs = []
    end

    # OVERRIDE
    def add_vertex(position, normal, uv)
      # TODO: check if inlining super() manually improves perfoemance here.
      super(position, normal)
      @vertices_uvs << uv
    end

    # Iterates over vertices. It takes a block with three parameters: position,
    # normal and UV coordinates.
    #
    # OVERRIDE
    def each_vertex
      i = 0
      @vertices_positions.each { |position|
        normal = @vertices_normals[i]
        uv = @vertices_uvs[i]
        yield position, normal, uv
        i += 1
      }
    end
  end

  # Definition of a compound 3-D mesh. A compound mesh consists of SketchUp
  # faces and other compound meshes (instances of compound meshes definitions).
  #
  # One definition of a compound mesh may be shared among multiple compound mesh
  # instances.
  #
  # Warning: Modifying the model a compound mesh definition is exported from may
  # invalidate the definition.
  class CompoundMeshDefinition
    def initialize
      # Array of SketchUp faces this compound mesh directly consists of.
      @faces = []

      # Array of compound mesh instances this compound mesh consists of.
      @submeshes = []
    end

    def add_face(face)
      @faces << face
    end

    def add_submesh(submesh)
      @submeshes << submesh
    end

    # TODO: How to make it private?
    POLY_MESH_INCLUDE_NORMALS = 4

    # Triangulates this compound mesh definition transformed by
    # +transformation+. Adds the result to +triangle_mesh+. All compound mesh
    # instances are exploded into a single triangle mesh.
    #
    # If the +triangle_mesh+ is UV mapped (is an object of
    # +UVMappedTriangleMesh+) then +texture_writer+ must be passed the
    # +TextureWriter+ object loaded with all the faces from this compound mesh
    # (ie. +texture_writer.load+ has been called for all these
    # faces). Otherwise, the +texture_writer+ is ignored.
    def triangulate_into(triangle_mesh, transformation, texture_writer=nil)
      change_orient = CompoundMeshDefinition.
        transformation_change_orientation?(transformation)

      uv_mapped = triangle_mesh.is_a? UVMappedTriangleMesh

      @faces.each { |face|
        # An index to offset indices of vertices of a SketchUp face to match the
        # indexing in +triangle_mesh+. Vertices of this face should receive
        # indices starting from +triangle_mesh.vertex_count+. SketchUp starts
        # indexing from 1, hence the "- 1".
        v_offset = triangle_mesh.vertex_count - 1

        face_mesh = face.mesh(POLY_MESH_INCLUDE_NORMALS)

        if uv_mapped then
          uv_helper = face.get_UVHelper(true, false, texture_writer)
        end

        i = 0
        face_mesh.points.each { |position|
          i += 1
          position = transformation * position
          normal = transformation * face_mesh.normal_at(i)
          # TODO: Should we normalize the normal?
          normal.normalize!
          if uv_mapped then
            uv = uv_helper.get_front_UVQ(position)
            triangle_mesh.add_vertex(position, normal, uv)
          else
            triangle_mesh.add_vertex(position, normal)
          end
        }

        face_mesh.polygons.each { |triangle|
          v0 = triangle[0].abs + v_offset
          v1 = triangle[1].abs + v_offset
          v2 = triangle[2].abs + v_offset
          if change_orient
            # If the face orientation was changed by transformation
            # we need to make it back clockwise.
            triangle_mesh.add_triangle([v0, v2, v1])
          else
            triangle_mesh.add_triangle([v0, v1, v2])
          end
        }
      }

      @submeshes.each { |submesh|
        submesh.triangulate_into(triangle_mesh, transformation, texture_writer)
      }
    end

    # Returns a boolean value telling if the transformation +t+ changes the
    # orientation from clockwise to counterclockwise and vice versa.
    #
    # TODO: Is there a way to make this method private?
    def self.transformation_change_orientation?(t)
      (t.xaxis * t.yaxis).dot(t.zaxis) < 0.0
    end
  end

  # Instance of a compound 3-D mesh.
  #
  # It is simply a compound mesh definition transformed relative to the instance
  # owner (eg. other compound mesh definition).
  #
  # Warning: Modifying the model a compound mesh instance is exported from may
  # invalidate the instance.
  class CompoundMeshInstance
    def initialize(definition, transformation)
      # Compound mesh definition.
      @definition = definition

      # Transformation applied to the compound mesh definition.
      @transformation = transformation
    end

    # Triangulates this compound mesh instance transformed by
    # +transformation+. Adds the result to +triangle_mesh+. All compound mesh
    # instances are exploded into a single triangle mesh.
    #
    # For meaning of +texture_writer+ see:
    # +CompoundMeshDefinition.triangulate_into+.
    def triangulate_into(triangle_mesh, transformation, texture_writer=nil)
      @definition.triangulate_into(triangle_mesh,
                                   transformation * @transformation,
                                   texture_writer)
    end
  end

  # Single-material 3-D part.
  #
  # "Single-material" means single external material.
  #
  # "Part" term is used to denote this entity instead of "object" because
  # "object" may be ambigous in an object oriented language. Also, the mesh
  # of one part may be very complex and use instances of other meshes, thus
  # one part may be translated to multiple 3-D objects of an external program.
  #
  # Warning: Modifying the model a part is exported from may invalidate the
  # part.
  class Part
    # External material of the part.
    attr_reader :external_material

    attr_reader :compound_mesh_def

    # Creates an empty 3-D part with the given external material.
    def initialize(external_material, mesh_def)
      @external_material = external_material

      # Compound mesh definition of the part.
      @compound_mesh_def = mesh_def
    end

    # Returns the triangle mesh produced by triangulating the compound mesh
    # definition of this part. All compound mesh instances are exploded into a
    # single triangle mesh.
    #
    # The +part_builder+ is the +PartBuilder+ object used to build this part.
    #
    # If the external material of this part requires UV mapping then the
    # +part_builder+ must be non-nil and the returned triangle mesh is
    # UV mapped (is an object of +UVMappedTriangleMesh+).
    def triangulate_mesh(part_builder=nil)
      identity = Geom::Transformation.new
      if @external_material.requires_uv_mapping?
        triangle_mesh = UVMappedTriangleMesh.new
        @compound_mesh_def.triangulate_into(triangle_mesh, identity,
                                            part_builder.texture_writer)
      else
        triangle_mesh = TriangleMesh.new
        @compound_mesh_def.triangulate_into(triangle_mesh, identity)
      end
      triangle_mesh
    end
  end

  # Class to build single-material 3-D parts for the given SketchUp entities.
  #
  # "Single-material" means single external material.
  #
  # This class builds parts from faces with the same external material.
  # (SketchUp) components and groups are not exploded. Component
  # definitions/groups are translated to multiple single-material mesh
  # definitions that are instanced in single-material parts (in a similar way
  # component/groups are instanced).
  class PartBuilder
    # TODO: proto
    attr_reader :texture_writer

    def initialize
      # SketchUp's +TextureWriter+ that will be loaded with textures used by
      # built parts.
      @texture_writer = Sketchup.create_texture_writer

      # single default external material.
      @default_ext_material = DefaultExternalMaterial.new

      # mapping SketchUp solid Material -> SolidExternalMaterial
      @solid_ext_materials = Hash.new

      # mapping (SketchUp textured Material, texture writer handle) ->
      #          TexturedExternalMaterial
      @textured_ext_materials = Hash.new

      # mapping ComponentDefinition -> [Part]: Keeps parts built for
      # a SketchUp component defintion.
      @comp_def_parts = Hash.new
    end

    # Builds single-material parts for the given SketchUp entities. Returns an
    # array of Part elements.
    def build_parts(entities)
      # mapping ExternalMaterial -> CompoundMeshDefinition: Keeps compound mesh
      # definitions built so far for each external material used in entities.
      mesh_defs = Hash.new

      entities.each { |entity|
        case entity
        when Sketchup::Group
          subparts = build_parts(entity.entities)
          # Incorporate +subparts+ inside +mesh_defs+.
          PartBuilder.add_subparts_meshes(mesh_defs, subparts,
                                          entity.transformation)
        when Sketchup::ComponentInstance
          comp_def = entity.definition
          # If parts for this component definition have been already built
          # reuse them.
          subparts = @comp_def_parts[comp_def]
          if not subparts
            # Parts have not been built yet. Build them now.
            subparts = build_parts(comp_def.entities)
            @comp_def_parts[comp_def] = subparts
          end
          # Incorporate +subparts+ inside +mesh_defs+.
          PartBuilder.add_subparts_meshes(mesh_defs, subparts,
                                          entity.transformation)
        when Sketchup::Face
          ext_material = build_external_material(entity)
          # Find a compound mesh definition for this external material.
          mesh_def = mesh_defs[ext_material]
          if not mesh_def
            # If there is no such a compound mesh create a fresh one.
            mesh_def = CompoundMeshDefinition.new
            mesh_defs[ext_material] = mesh_def
          end
          mesh_def.add_face(entity)
        end
      }

      # Create parts from +mesh_defs+ and return them.
      parts = []
      mesh_defs.each { |ext_material, mesh_def|
        parts << Part.new(ext_material, mesh_def)
      }
      parts
    end

    # Instantiates compound mesh definitions of +subparts+ inside +mesh_defs+
    # for corresponding external materials using the given +transformation+.
    #
    # TODO: Is there a way to make this method private?
    def self.add_subparts_meshes(mesh_defs, subparts, transformation)
      subparts.each { |subpart|
        # Instantiate the compound mesh definition of subpart using the given
        # +transformation+.
        submesh = CompoundMeshInstance.new(subpart.compound_mesh_def,
                                           transformation)
        ext_material = subpart.external_material
        mesh_def = mesh_defs[ext_material]
        if not mesh_def
          # If there is no compound mesh definition for +ext_material+ create
          # one.
          mesh_def = CompoundMeshDefinition.new
          mesh_defs[ext_material] = mesh_def
        end
        mesh_def.add_submesh(submesh)
      }
    end

    MATERIAL_TYPE_SOLID = 0
    MATERIAL_TYPE_TEXTURED = 1

    # Build or reuse existing external material for the given SketchUp face.
    def build_external_material(face)
      su_material = face.material

      if su_material == nil
        # Nil material means default material.
        return @default_ext_material
      end

      if su_material.materialType == MATERIAL_TYPE_SOLID
        # Look for existing external material for this SketchUp solid material.
        ext_material = @solid_ext_materials[su_material]
        if not ext_material
          # Create one, if it does not exist.
          ext_material = SolidExternalMaterial.new(su_material)
          @solid_ext_materials[su_material] = ext_material
        end
      elsif su_material.materialType == MATERIAL_TYPE_TEXTURED
        # Load the face to the texture writer.
        handle = @texture_writer.load(face, true)
        
        # SketchUp textured material does not necessarily correspond
        # to a single textured external material (see: comments for the
        # +TexturedExternalMaterial+ class). Different values of
        # handle returned by texture writer for the same SketchUp material
        # means there will be different pretransformed textures for the same
        # material, and thus there should be different external material.
        ext_material_key = [su_material, handle]

        # Look for existing external material for this face.
        ext_material = @textured_ext_materials[ext_material_key]
        if not ext_material
          # Create one, if it does not exist.
          ext_material = TexturedExternalMaterial.new(su_material, face)
          @textured_ext_materials[ext_material_key] = ext_material
        end
      else
        # TODO: better material name
        # TODO: tmp turn off p('Unknown material type: ' + su_material.name)
        ext_material = @default_ext_material
      end

      ext_material
    end
    private :build_external_material
  end

  # TODO: proto, exceptions, comments, doc
  class SceneExporter
    def initialize(path, file_name_root)
      @path = path
      @file_name_root = file_name_root
    end
	
    def export_scene
      export_config

      export_description
    end

    def export_config
      file = File.new(@path + '\\' + @file_name_root + '.cfg', 'w')

      file.write('scene.file=' + @file_name_root + ".scn\n")
		
      file.write('image.filename=' + @file_name_root + ".png\n")
      file.write("image.width = 800\n")
      file.write("image.height = 600\n")

      file.write("renderengine.type = PATHCPU\n")
		
      file.close
    end
    private :export_config
	
    def export_description
      part_builder = PartBuilder.new
      parts = part_builder.build_parts(Sketchup.active_model.entities)

      file = File.new(@path + '\\' + @file_name_root + '.scn', 'w')
	
      export_description_header(file)
		
      id = 0
      parts.each { |part|
        id += 1

        ext_material = part.external_material
        ext_material_name = ext_material.name

        if ext_material.is_a? TexturedExternalMaterial
          tex_file_ext = ext_material.file_name_extension
          tex_file_name = "#{id}#{tex_file_ext}"
          begin
            ext_material.write_texture(@path + '\\' + tex_file_name,
                                       part_builder)
          rescue TextureWriterError => e
            p e.message
            file.write("scene.materials.\"#{ext_material_name}\".type=matte\n")
            file.write("scene.materials.\"#{ext_material_name}\".kd=1 1 1\n")
          else
            file.write("scene.textures.\"#{ext_material_name}\".type="\
                       "imagemap\n")
            file.write("scene.textures.\"#{ext_material_name}\".file="\
                       "#{tex_file_name}\n")
            file.write("scene.materials.\"#{ext_material_name}\".type=matte\n")
            file.write("scene.materials.\"#{ext_material_name}\".kd="\
                       "\"#{ext_material_name}\"\n")
          end
        elsif ext_material.is_a? SolidExternalMaterial
          color = ext_material.sketchup_material.color
          color_str = "%.3f %.3f %.3f" %
            [color.red / 255.0, color.green / 255.0, color.blue / 255.0]
          file.write("scene.materials.\"#{ext_material_name}\".type=matte\n")
          file.write("scene.materials.\"#{ext_material_name}\".kd="\
                     "#{color_str}\n")
        elsif ext_material.is_a? DefaultExternalMaterial
          file.write("scene.materials.\"#{ext_material_name}\".type=matte\n")
          file.write("scene.materials.\"#{ext_material_name}\".kd=1 1 1\n")
        end

        triangle_mesh = part.triangulate_mesh(part_builder)
        export_triangle_mesh(id, triangle_mesh)

        file.write("scene.objects.#{id}.ply=#{id}.ply\n")
        file.write("scene.objects.#{id}.useplynormals=1\n")
        file.write("scene.objects.#{id}.material=\"#{ext_material_name}\"\n")
      }

      file.close
    end
    private :export_description

    def export_description_header(file)
      camera = Sketchup.active_model.active_view.camera
      sun_dir = Sketchup.active_model.shadow_info['SunDirection']

      file.write("scene.camera.lookat=%.6f %.6f %.6f %.6f %.6f %.6f\n" %
                 [camera.eye.x, camera.eye.y, camera.eye.z,
                  camera.target.x, camera.target.y, camera.target.z])
      file.write("scene.camera.up=%.6f %.6f %.6f\n" %
                 [camera.up.x, camera.up.y, camera.up.z])
      file.write("scene.camera.fieldofview=70.0\n")
      file.write("scene.sunlight.dir=%.6f %.6f %.6f\n" %
                 [sun_dir.x, sun_dir.y, sun_dir.z])
      file.write("scene.skylight.dir=%.6f %.6f %.6f\n" %
                 [sun_dir.x, sun_dir.y, sun_dir.z])
    end
    private :export_description_header

    def export_triangle_mesh(id, triangle_mesh)
      uv_mapped = triangle_mesh.is_a? UVMappedTriangleMesh

      file = File.new(@path + '\\' + id.to_s + '.ply', 'wb')
      
      file.write("ply\n")
      file.write("format ascii 1.0\n")
      file.write("element vertex #{triangle_mesh.vertex_count}\n")
      file.write("property float x\n")
      file.write("property float y\n")
      file.write("property float z\n")
      file.write("property float nx\n")
      file.write("property float ny\n")
      file.write("property float nz\n")
      if uv_mapped
        file.write("property float s\n")
        file.write("property float t\n")
      end
      file.write("element face #{triangle_mesh.triangle_count}\n")
      file.write("property list uchar uint vertex_indices\n")
      file.write("end_header\n")

      if uv_mapped
        triangle_mesh.each_vertex { |position, normal, uv|
          # TODO: why -uv?
          file.write("%.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f\n" %
                     [position.x, position.y, position.z,
                      normal.x, normal.y, normal.z, uv.x, -uv.y])
        }
      else
        triangle_mesh.each_vertex { |position, normal|
          file.write("%.6f %.6f %.6f %.6f %.6f %.6f\n" %
                     [position.x, position.y, position.z,
                      normal.x, normal.y, normal.z])
        }
      end

      triangle_mesh.each_triangle { |triangle|
        file.write("3 %d %d %d\n" % triangle)
      }

      file.close
    end
    private :export_triangle_mesh

    # TODO: windows only for now
    def export_triangle_mesh_bin(id, triangle_mesh)
      uv_mapped = triangle_mesh.is_a? UVMappedTriangleMesh

      file = File.new(@path + '\\' + id.to_s + '.ply', 'wb')
      
      file.write("ply\n")
      file.write("format binary_little_endian 1.0\n")
      file.write("element vertex #{triangle_mesh.vertex_count}\n")
      file.write("property float x\n")
      file.write("property float y\n")
      file.write("property float z\n")
      file.write("property float nx\n")
      file.write("property float ny\n")
      file.write("property float nz\n")
      if uv_mapped
        file.write("property float s\n")
        file.write("property float t\n")
      end
      file.write("element face #{triangle_mesh.triangle_count}\n")
      file.write("property list uchar uint vertex_indices\n")
      file.write("end_header\n")

      if uv_mapped
        triangle_mesh.each_vertex { |position, normal, uv|
          # TODO: why -uv?
          buf = [position.x, position.y, position.z,
                 normal.x, normal.y, normal.z, uv.x, -uv.y].pack('e8')
          file.write(buf)
        }
      else
        triangle_mesh.each_vertex { |position, normal|
          buf = [position.x, position.y, position.z,
                 normal.x, normal.y, normal.z].pack('e6')
          file.write(buf)
        }
      end

      triangle_mesh.each_triangle { |triangle|
        buf = "\003" + triangle.pack('I3')
        file.write(buf)
      }

      file.close
    end
    private :export_triangle_mesh_bin
  end	

  # Temporary method to run the builder from the Ruby Console
  def self.build_all
    t = Time.new
    PartBuilder.new.build_parts(Sketchup.active_model.entities)
    t = Time.new - t
    UI.messagebox("Time taken: #{t}")
  end

  # Temporary method to run the builder from the Ruby Console
  def self.build_selection
    t = Time.new
    PartBuilder.new.build_parts(Sketchup.active_model.selection)
    t = Time.new - t
    UI.messagebox("Time taken: #{t}")
  end

  # Temporary method to run the exporter from the Ruby Console
  def self.export_all(path)
    t = Time.new
    exporter = SceneExporter.new(path, 'scene')
    exporter.export_scene
    t = Time.new - t
    UI.messagebox("Time taken: #{t}")
  end

end
