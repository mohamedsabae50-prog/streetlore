import re

file_path = r'd:\codes\streetlore\lib\data\mock_data.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = {
    'fallback_qaitbay': 'قلعة قايتباي هي حصن دفاعي يعود للقرن الخامس عشر الميلادي، مبني على أنقاض منارة الإسكندرية القديمة، إحدى عجائب الدنيا السبع. تقع على شاطئ البحر المتوسط وتتميز بمعمارها الأيوبي الرائع.',
    'fallback_biblio': 'مكتبة الإسكندرية الجديدة صرح ثقافي ضخم على شاطئ البحر المتوسط، تجسيد معاصر للمكتبة الأسطورية التي كانت مركزاً للعلوم والمعرفة في العالم القديم. تضم مليوني كتاب ومتاحف وقاعات عروض.',
    'fallback_pompey': 'عمود بومبي عمود ضخم من الجرانيت يعود للعصر الروماني، يبلغ ارتفاعه 26 متراً، وهو أعلى عمود انتصار خارج روما. أُقيم عام 297 م تكريماً للإمبراطور دقلديانوس.',
    'fallback_catacombs': 'مقابر كوم الشقافة من أبرز المواقع الأثرية في الإسكندرية، تُعد إحدى عجائب الدنيا السبع في العصر الوسيط. متاهة متعددة الطوابق تمزج بين الفن الروماني والمصري القديم.',
    'fallback_corniche': 'كورنيش الإسكندرية ممشى ساحلي خلاب يمتد على طول البحر المتوسط. من أجمل الكورنيشات في مصر، مثالي لجلسات الغروب والتنزه مع الأسرة.',
    'fallback_montaza': 'حدائق المنتزه الملكية خضراء غناء تحيط بقصر المنتزه التاريخي الذي بناه الخديوي عباس. واحة طبيعية خلابة تطل على البحر المتوسط وتجمع بين الجمال والتاريخ.',
    'fallback_attarine': 'مسجد العطارين أحد المساجد التاريخية العريقة في قلب الإسكندرية القديمة. يعود تاريخه للعصر المملوكي ويتميز بزخارفه الإسلامية الرائعة وروحانيته العالية.',
    'fallback_stmark': 'كاتدرائية القديس مرقس الأرثوذكسية مقر البابا الكوبي التاريخي في الإسكندرية. تجمع بين الإرث الكنسي الأصيل والعمارة الحديثة في قلب مدينة الإسكندرية.'
}

# The structure is PlaceModel(id: '...', ..., description: '...', ...)
# We can use regex to find id: 'X' and then insert descriptionAr after description.

def replacer(match):
    full_match = match.group(0)
    id_val = match.group(1)
    desc = match.group(2)
    
    if id_val in replacements:
        desc_ar = replacements[id_val]
        # Insert descriptionAr after description
        # We find the end of description and append
        desc_end = full_match.find(desc) + len(desc)
        # Check if descriptionAr is already there
        if 'descriptionAr' not in full_match:
            new_match = full_match[:desc_end] + f\",\n        descriptionAr: '{desc_ar}'\" + full_match[desc_end:]
            return new_match
    return full_match

# We want to match from id: to the end of description string.
pattern = r\"id:\s*'([^']+)'(?:.|\n)*?description:\s*('.*?'|\".*?\")\"
new_content = re.sub(pattern, replacer, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Done modifying mock_data.dart')
