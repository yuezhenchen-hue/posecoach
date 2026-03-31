"""初始化种子数据：将内置的 Pose 模板和配置写入数据库"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import init_db, async_session
from app.models.pose import PoseTemplate, SceneTip
from app.models.config import AppConfig


POSES = [
    # 海边
    ("beach_01", "背影看海", "面朝大海，微微侧头，风吹头发", "beach", "single", "easy"),
    ("beach_02", "踩浪花", "站在浪花边缘，抬脚踩水，表情自然开心", "beach", "single", "easy"),
    ("beach_03", "沙滩奔跑", "自然奔跑，连拍抓拍最佳瞬间", "beach", "single", "medium"),
    ("beach_04", "纱巾飘动", "手持纱巾让风吹起，营造飘逸感", "beach", "single", "medium"),
    ("beach_05", "情侣牵手", "面朝大海牵手，拍背影或侧面", "beach", "couple", "easy"),
    # 城市街拍
    ("city_01", "回眸一笑", "自然走路，回头看镜头微笑", "cityStreet", "single", "easy"),
    ("city_02", "靠墙站", "一脚靠墙，侧身45度，看向远方", "cityStreet", "single", "easy"),
    ("city_03", "走路抓拍", "自然行走，低角度拍摄显腿长", "cityStreet", "single", "medium"),
    ("city_04", "斑马线", "站在斑马线中间，利用线条做引导线", "cityStreet", "single", "easy"),
    # 咖啡厅
    ("cafe_01", "窗边阅读", "侧坐窗边，低头看书/手机，自然光照脸", "cafe", "single", "easy"),
    ("cafe_02", "手托腮", "手肘撑桌，手托腮微笑，前方放咖啡杯", "cafe", "single", "easy"),
    ("cafe_03", "举杯微笑", "双手捧杯，杯沿靠近嘴边，眼神看向窗外", "cafe", "single", "easy"),
    # 日落
    ("sunset_01", "剪影伸手", "面朝夕阳伸出手，拍剪影效果", "sunset", "single", "medium"),
    ("sunset_02", "举手触阳", "手举起假装触碰太阳，创意构图", "sunset", "single", "medium"),
    ("sunset_03", "情侣剪影", "面对面靠近，拍双人剪影", "sunset", "couple", "medium"),
    # 自然/花园
    ("nature_01", "花丛半遮面", "站在花丛中，花遮住半边脸", "garden", "single", "easy"),
    ("nature_02", "闻花香", "微微低头闻花，表情陶醉自然", "garden", "single", "easy"),
    ("nature_03", "森林漫步", "走在林间小路，回头看镜头", "nature", "single", "easy"),
    # 夜景
    ("night_01", "霓虹背景", "面朝镜头，霓虹灯做光斑背景", "nightScene", "single", "medium"),
    ("night_02", "路灯下", "站在路灯下，利用顶光营造氛围", "nightScene", "single", "medium"),
    # 通用
    ("general_01", "自然站立", "微侧身，一手插兜，重心放一条腿", "unknown", "single", "easy"),
    ("general_02", "坐姿放松", "找台阶/栏杆坐下，双腿自然交叉", "unknown", "single", "easy"),
    ("general_03", "抬头仰望", "微微抬头看天空，表情放松", "unknown", "single", "easy"),
]

SCENE_TIPS = [
    ("beach", "creative", "利用浪花做前景"),
    ("beach", "creative", "脚踩沙滩留下脚印"),
    ("beach", "creative", "用纱巾增加飘逸感"),
    ("beach", "creative", "剪影效果（逆光降曝光）"),
    ("beach", "parameter", "建议开启 HDR 应对海天大光比"),
    ("sunset", "creative", "剪影效果最佳时机"),
    ("sunset", "creative", "利用暖色光拍人物侧脸"),
    ("sunset", "parameter", "曝光降低1-2档拍剪影"),
    ("cityStreet", "creative", "利用道路做引导线"),
    ("cityStreet", "creative", "蹲低拍出大长腿"),
    ("cityStreet", "creative", "利用橱窗反射"),
    ("cafe", "creative", "窗边自然光最佳"),
    ("cafe", "creative", "利用咖啡杯做前景"),
    ("cafe", "parameter", "室内建议关闭闪光灯用自然光"),
    ("nature", "creative", "利用花丛做前景虚化"),
    ("nature", "creative", "找框架构图（树枝/石洞）"),
    ("nightScene", "creative", "利用霓虹灯做背景光斑"),
    ("nightScene", "parameter", "保持手机稳定，可靠在固定物上"),
]

DEFAULT_CONFIGS = {
    "poses_version": "1.0.0",
    "min_app_version": "1.0.0",
    "latest_app_version": "1.0.0",
    "maintenance_mode": "false",
    "announcement": "",
    "max_free_photo_match_per_day": "3",
    "voice_coach_default_enabled": "true",
    "default_composition_guide": "ruleOfThirds",
}


async def seed():
    await init_db()
    async with async_session() as session:
        # Poses
        for p in POSES:
            session.add(PoseTemplate(
                id=p[0], name=p[1], description=p[2],
                scene=p[3], person_count=p[4], difficulty=p[5],
            ))

        # Scene tips
        for i, (scene, tip_type, content) in enumerate(SCENE_TIPS):
            session.add(SceneTip(
                scene=scene, tip_type=tip_type, content=content, sort_order=i,
            ))

        # Configs
        for key, value in DEFAULT_CONFIGS.items():
            session.add(AppConfig(key=key, value=value))

        await session.commit()
        print(f"Seeded {len(POSES)} poses, {len(SCENE_TIPS)} tips, {len(DEFAULT_CONFIGS)} configs")


if __name__ == "__main__":
    asyncio.run(seed())
