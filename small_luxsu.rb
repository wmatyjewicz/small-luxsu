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

  # Material for external use (outside of SketchUp).
  #
  # Instances of this class represent materials from the perspective of an
  # external program.
  #
  # Not every SketchUp material can be translated to a single material of an
  # external program (see comments for +TexturedExternalMaterial+). In such a
  # case the SketchUp material is translated to multiple external materials.
  class ExternalMaterial
  end

  # Default material for external use (outside of SketchUp).
  #
  # The default SketchUp material is always translated to one external material.
  class DefaultExternalMaterial < ExternalMaterial
  end

  # Solid (colored, not textured) material for external use (outside of
  # SketchUp).
  #
  # A solid SketchUp material is always translated to one external material.
  class SolidExternalMaterial < ExternalMaterial
    # SketchUp material this external material represents.
    attr_reader :sketchup_material

    def initialize(sketchup_material)
      @sketchup_material = sketchup_material
    end
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
  class TexturedExternalMaterial < ExternalMaterial
    # SketchUp material this external material correspond to.
    attr_reader :sketchup_material

    # A sample face with this external material.
    attr_reader :sample_face

    def initialize(sketchup_material, sample_face)
      @sketchup_material = sketchup_material
      @sample_face = sample_face
    end
  end

  # Definition of a 3-D mesh.
  #
  # One definition of a mesh may be shared among multiple mesh instances.
  #
  # Warning: Modifying the model a mesh definition is exported from may
  # invalidate the mesh definition.
  class Mesh3dDefinition
    # Array of SketchUp faces this mesh directly consists of.
    attr_reader :faces

    # Array of mesh instances this mesh consists of.
    attr_reader :submeshes

    def initialize
      @faces = []
      @submeshes = []
    end

    def add_face(face)
      @faces << face
    end

    def add_submesh(submesh)
      @submeshes << submesh
    end
  end

  # Instance of a 3-D mesh.
  #
  # It is simply a mesh definition transformed relative to the instance owner
  # (eg. other mesh definition).
  #
  # Warning: Modifying the model a mesh instance is exported from may invalidate
  # the mesh instance.
  class Mesh3dInstance
    # Mesh definition.
    attr_reader :definition

    # Transformation applied to mesh definition.
    attr_reader :transformation

    def initialize(definition, transformation)
      @definition = definition
      @transformation = transformation
    end
  end

  # Single-material 3-D object.
  #
  # "Single-material" means single external material.
  #
  # Warning: Modifying the model an object is exported from may invalidate the
  # object.
  class Object3d
    # External material of the object.
    attr_reader :external_material

    # Mesh definition of the object.
    attr_reader :mesh_definition

    # Creates an empty 3-D object with the given external material.
    def initialize(external_material)
      @external_material = external_material
      @mesh_definition = Mesh3dDefinition.new
    end
  end

  # Class to build single-material 3-D objects for the given SketchUp entities.
  #
  # "Single-material" means single external material.
  #
  # This class builds objects from faces with the same external material.
  # (SketchUp) components and groups are not exploded. Component
  # definitions/groups are translated to multiple single-material mesh
  # definitions that are instanced in single-material objects (in a similar way
  # component/groups are instanced).
  class Object3dBuilder
    def initialize
      # SketchUp's +TextureWriter+ that will be loaded with textures used by
      # built objects.
      @texture_writer = Sketchup.create_texture_writer

      # single default external material.
      @default_ext_material = DefaultExternalMaterial.new

      # mapping SketchUp solid Material -> SolidExternalMaterial
      @solid_ext_materials = Hash.new

      # mapping (SketchUp textured Material, texture writer handle) ->
      #           TexturedExternalMaterial
      @textured_ext_materials = Hash.new

      # mapping ComponentDefinition -> [Object3d]: Keeps objects built for
      # a SketchUp component defintion.
      # TODO: ComponentDefinition and not String as a key?
      @comp_def_objects = Hash.new
    end

    # Builds single-material objects for the given SketchUp entities.
    # Returns an array of Object3d elements.
    def build_objects(entities)
      # mapping ExternalMaterial -> Object3d: Keeps object built so far for
      # each external material used in entities.
      objects = Hash.new

      entities.each { |entity|
        case entity
        when Sketchup::Group
          subobjects = build_objects(entity.entities)
          # Incorporate subobjects inside objects.
          add_subobjects_meshes(objects, subobjects, entity.transformation)
        when Sketchup::ComponentInstance
          comp_def = entity.definition
          # If objects for this component definition have been already built
          # reuse them.
          subobjects = @comp_def_objects[comp_def]
          if not subobjects
            # Objects have not been built yet. Build them now.
            subobjects = build_objects(comp_def.entities)
            @comp_def_objects[comp_def] = subobjects
          end
          # Incorporate subobjects inside objects.
          add_subobjects_meshes(objects, subobjects, entity.transformation)
        when Sketchup::Face
          ext_material = build_external_material(entity)
          object = objects[ext_material]
          if not object
            object = Object3d.new(ext_material)
            objects[ext_material] = object
          end
          object.mesh_definition.add_face(entity)
        end
      }

      return objects.values
    end

    # Instantiates mesh definitions of +subobjects+ inside +objects+ of
    # corresponding external materials using the given +transformation+.
    # TODO: This method could be class-level method.
    def add_subobjects_meshes(objects, subobjects, transformation)
      subobjects.each { |subobject|
        # Instantiate the mesh definition of subobject. It is transformed 
        # relative to the to object it will be incorported into.
        submesh = Mesh3dInstance.new(subobject.mesh_definition, transformation)
        ext_material = subobject.external_material
        object = objects[ext_material]
        if not object
          # If there is no such an object create a fresh one.
          object = Object3d.new(ext_material)
          objects[ext_material] = object
        end
        object.mesh_definition.add_submesh(submesh)
      }
    end
    private :add_subobjects_meshes

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
        p("Unknown material type: " + su_material.name)
        ext_material = @default_ext_material
      end

      return ext_material
    end
    private :build_external_material
  end

  # Temporary method to run the builder from the Ruby Console
  def self.build_all
    t = Time.new
    Object3dBuilder.new.build_objects(Sketchup.active_model.entities)
    t = Time.new - t
    UI.messagebox("Time taken: " + t.to_s)
    return nil # to avoid displaying the whole model in the Ruby Console
  end

  # Temporary method to run the builder from the Ruby Console
  def self.build_selection
    t = Time.new
    Object3dBuilder.new.build_objects(Sketchup.active_model.selection)
    t = Time.new - t
    UI.messagebox("Time taken: " + t.to_s)
    return nil # to avoid displaying the whole model in the Ruby Console
  end

end # module SmallLuxSU
