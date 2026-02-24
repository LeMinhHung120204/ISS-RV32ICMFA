import os
import re
import glob

def fix_port_syntax(content):
    """
    Sửa cú pháp khai báo port của module Verilog:
    - Dòng đầu tiên: không có dấu phẩy
    - Từ dòng thứ 2 trở đi: thêm dấu , ở đầu dòng
    
    Chuyển từ:
        input   clk,
        input   rst_n,
        output  data
    
    Sang:
        input   clk
    ,   input   rst_n
    ,   output  data
    """
    
    # Pattern để tìm module port list
    # Tìm phần trong ngoặc () sau tên module (có thể có parameter)
    
    def fix_ports(match):
        ports_block = match.group(0)
        
        # Tách các dòng
        lines = ports_block.split('\n')
        result_lines = []
        
        first_port_found = False
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Skip empty lines, comments, opening/closing parentheses
            if not stripped or stripped.startswith('//') or stripped == '(' or stripped == ')' or stripped == ');':
                result_lines.append(line)
                continue
            
            # Kiểm tra xem dòng này có phải là port declaration không
            is_port = re.match(r'^(input|output|inout)\b', stripped)
            
            if is_port:
                # Xóa dấu phẩy ở cuối nếu có
                line_no_trailing_comma = re.sub(r',\s*$', '', line)
                line_no_trailing_comma = re.sub(r',\s*(//.*)?$', r' \1' if '// ' in line else '', line)
                
                # Xử lý dấu phẩy ở cuối dòng (bao gồm cả comment)
                if ',' in line:
                    # Tìm và xóa dấu phẩy cuối (trước comment nếu có)
                    line_no_trailing_comma = re.sub(r',(\s*)(//.*)?$', r'\1\2', line)
                else:
                    line_no_trailing_comma = line
                
                if not first_port_found:
                    # Dòng port đầu tiên - không thêm dấu phẩy
                    first_port_found = True
                    # Xóa dấu phẩy đầu dòng nếu có
                    line_no_trailing_comma = re.sub(r'^(\s*),\s*', r'\1    ', line_no_trailing_comma)
                    result_lines.append(line_no_trailing_comma)
                else:
                    # Từ dòng thứ 2 trở đi - thêm , ở đầu
                    # Kiểm tra xem đã có , ở đầu chưa
                    if re.match(r'^\s*,', line_no_trailing_comma):
                        # Đã có dấu phẩy ở đầu
                        result_lines.append(line_no_trailing_comma)
                    else:
                        # Chưa có, thêm vào
                        # Lấy số space đầu dòng
                        leading_spaces = len(line_no_trailing_comma) - len(line_no_trailing_comma.lstrip())
                        if leading_spaces >= 4:
                            new_line = line_no_trailing_comma[:leading_spaces-4] + ',   ' + line_no_trailing_comma[leading_spaces:]
                        else:
                            new_line = ',   ' + line_no_trailing_comma.lstrip()
                        result_lines.append(new_line)
            else:
                result_lines.append(line)
        
        return '\n'.join(result_lines)
    
    # Xử lý từng module
    # Tìm pattern: module name #(...) ( ports );
    # hoặc: module name ( ports );
    
    result = content
    
    # Tìm tất cả các port list blocks
    # Pattern: tìm phần trong () sau )( hoặc module_name(
    
    # Approach đơn giản hơn: xử lý từng dòng trong file
    lines = content.split('\n')
    in_port_list = False
    first_port_in_current_module = False
    paren_depth = 0
    result_lines = []
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Detect start of module port list
        if re.search(r'\)\s*\(\s*$', stripped) or re.search(r'^module\s+\w+\s*\(\s*$', stripped):
            in_port_list = True
            first_port_in_current_module = True
            result_lines.append(line)
            continue
        
        # Detect end of port list
        if in_port_list and (stripped == ');' or stripped.endswith(');')):
            in_port_list = False
            result_lines.append(line)
            continue
        
        if in_port_list:
            # Kiểm tra xem có phải port declaration không
            is_port = re.match(r'^,?\s*(input|output|inout)\b', stripped)
            
            if is_port:
                # Xóa dấu phẩy cuối dòng (giữ lại comment nếu có)
                new_line = re.sub(r',(\s*)(//.*)?$', r'\1\2', line)
                
                if first_port_in_current_module:
                    first_port_in_current_module = False
                    # Dòng đầu tiên - xóa dấu phẩy đầu nếu có
                    new_line = re.sub(r'^(\s*),\s*', r'\1    ', new_line)
                    result_lines.append(new_line)
                else:
                    # Từ dòng thứ 2 - thêm dấu phẩy đầu
                    if re.match(r'^\s*,', new_line):
                        # Đã có dấu phẩy ở đầu
                        result_lines.append(new_line)
                    else:
                        # Thêm dấu phẩy ở đầu
                        leading_spaces = len(new_line) - len(new_line.lstrip())
                        if leading_spaces >= 4:
                            new_line = new_line[:leading_spaces-4] + ',   ' + new_line[leading_spaces:]
                        else:
                            new_line = ',   ' + new_line.lstrip()
                        result_lines.append(new_line)
            else:
                result_lines.append(line)
        else:
            result_lines.append(line)
    
    return '\n'.join(result_lines)


def process_file(filepath):
    """Process a single Verilog file"""
    try:
        # Try multiple encodings
        content = None
        encoding_used = None
        for enc in ['utf-8', 'latin-1', 'cp1252']:
            try:
                with open(filepath, 'r', encoding=enc) as f:
                    content = f.read()
                encoding_used = enc
                break
            except UnicodeDecodeError:
                continue
        
        if content is None:
            print(f"Could not read {filepath} with any encoding")
            return False
        
        new_content = fix_port_syntax(content)
        
        if new_content != content:
            with open(filepath, 'w', encoding=encoding_used) as f:
                f.write(new_content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False


def main():
    # Tìm tất cả file .v trong thư mục pipeline
    base_dir = os.path.dirname(os.path.abspath(__file__))
    pipeline_dir = os.path.join(base_dir, 'pipeline')
    
    verilog_files = glob.glob(os.path.join(pipeline_dir, '**', '*.v'), recursive=True)
    
    modified_count = 0
    for filepath in verilog_files:
        if process_file(filepath):
            print(f"Modified: {filepath}")
            modified_count += 1
    
    print(f"\nTotal files modified: {modified_count}/{len(verilog_files)}")


if __name__ == '__main__':
    main()
