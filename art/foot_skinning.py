"""Conserve skin weights while preventing toe joints from folding solid boots."""


def correct(objects,mode="toe"):
    report=[]
    for obj in objects:
        counts={}
        if mode in ("toe","both"):
            for side in ("Left","Right"):
                foot=obj.vertex_groups.get(side+"Foot")
                toe=obj.vertex_groups.get(side+"ToeBase")
                if foot is None or toe is None:continue
                changed=[]
                for vertex in obj.data.vertices:
                    weights={entry.group:entry.weight for entry in vertex.groups}
                    toe_weight=weights.get(toe.index,0)
                    if toe_weight<=0:continue
                    combined=weights.get(foot.index,0)+toe_weight
                    assert combined<=1.0001
                    foot.add([vertex.index],combined,"REPLACE")
                    changed.append(vertex.index)
                if changed:toe.remove(changed)
                counts[side]=len(changed)
        for modifier in obj.modifiers:
            if modifier.type=="ARMATURE":modifier.use_deform_preserve_volume=mode in ("volume","both")
        report.append({"object":obj.name,"mode":mode,"toe_weights_transferred":counts,"geometry_edited":False,"textures_edited":False,"other_bone_weights_retained":True})
    return report
