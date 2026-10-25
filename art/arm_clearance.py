"""Give the left arm room to swing outside the skirt, using the existing rig."""
import bpy,math
from mathutils import Matrix


def correct(rig):
    source=rig.animation_data.action
    start,end=map(float,source.frame_range)
    bone=rig.pose.bones['LeftArm']
    bone.rotation_mode='QUATERNION'
    samples=[]
    angle=math.radians(-8)
    for step in range(65):
        at=start+(end-start)*step/64
        bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
        original=rig.matrix_world@bone.matrix
        pivot=original.translation
        adjusted=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,'Y')@Matrix.Translation(-pivot)@original
        bone.matrix=rig.matrix_world.inverted()@adjusted
        samples.append((at,bone.rotation_quaternion.copy()))
    action=source.copy();action.name=source.name+'_left_arm_clearance'
    rig.animation_data.action=action
    for at,rotation in samples:
        bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
        bone.rotation_quaternion=rotation
        bone.keyframe_insert('rotation_quaternion',frame=at,group=bone.name)
    return {'method':'Left upper arm rotated outward 8 degrees through the existing walk; elbow and wrist animation preserved','baked_poses':65,'source_action_retained':source.name}
