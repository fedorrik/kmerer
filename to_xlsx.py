import os
import pandas as pd
from sys import argv

directory = argv[1]
xlsx_file_path = argv[2]

# Получаем список файлов .tsv в указанной директории
tsv_files = [file for file in os.listdir(directory) if file.endswith('.cnt')]

# Создаем новый объект ExcelWriter
with pd.ExcelWriter(xlsx_file_path, engine='xlsxwriter') as writer:
    # Проходимся по всем файлам .tsv
    for file in tsv_files:
        # Читаем данные из каждого файла .tsv в pandas DataFrame
        df = pd.read_csv(os.path.join(directory, file), sep='\t')
        # Используем имя файла (без расширения) в качестве имени листа в Excel
        sheet_name = os.path.splitext(file)[0]
        # Записываем данные в Excel на отдельный лист
        df.to_excel(writer, sheet_name=sheet_name, index=False)

print("xlsx created")

from openpyxl import load_workbook

# Укажите путь к существующему файлу Excel


# Загружаем существующий файл Excel
workbook = load_workbook(xlsx_file_path)

# Проходимся по всем листам в книге
for sheet in workbook.sheetnames:
    # Получаем активный лист
    ws = workbook[sheet]
    # Устанавливаем ширину первой колонки до 20 (вы можете изменить это значение)
    ws.column_dimensions['A'].width = 30

# Сохраняем изменения в файл Excel
workbook.save(xlsx_file_path)

print("first column width set to 30")


