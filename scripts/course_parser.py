import json
from bs4 import BeautifulSoup

def parse_graduation_data(html_path, output_path):
    with open(html_path, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'html.parser')
    
    # Get all rows (not just the center-aligned ones, to catch everything)
    rows = soup.find_all('tr')
    
    categories = {
        "Compulsory": {"required": 30, "courses": []},
        "General Education": {"required": 28, "courses": []},
        "Electives": {"required": 40, "courses": []},
        "PE & Service": {"required": 0, "courses": []}
    }

    total_grade_points = 0.0
    total_gpa_credits = 0

    for row in rows:
        tds = row.find_all('td')
        if not tds: continue

        # --- 1. PARSE SUMMARY ROWS (For Cumulative GPA) ---
        # The summary rows have many columns (~17)
        if len(tds) >= 16:
            gpa_str = tds[2].get_text(strip=True)
            credits_str = tds[6].get_text(strip=True) # "Deserved Credits"
            
            # If the GPA is valid (not '**') and credits is a number
            if gpa_str and gpa_str != '**' and credits_str.isdigit():
                try:
                    gpa = float(gpa_str)
                    creds = int(credits_str)
                    total_grade_points += gpa * creds
                    total_gpa_credits += creds
                except ValueError:
                    pass
            continue

        # --- 2. PARSE COURSE ROWS ---
        if len(tds) < 6: continue
        
        raw_credits = tds[4].get_text(strip=True)
        try:
            credits = int(float(raw_credits if raw_credits else 0))
        except ValueError:
            continue # Skips headers like "Relative Grade Average"

        code = tds[2].get_text(strip=True)
        if not code or "School Semester" in code: continue

        name_bits = tds[3].get_text(separator="|", strip=True).split("|")
        title = name_bits[2] if len(name_bits) > 2 else name_bits[0]
        grade = tds[5].get_text(strip=True)
        
        status = "passed"
        if "Grade Not Submitted" in grade or "成績未到" in grade:
            status = "inProgress"
        elif grade in ["E", "X", "F"]:
            status = "failed"
        elif "Withdrawn" in grade or "停修" in grade:
            continue

        record = {
            "title": title,
            "credits": credits,
            "grade": grade if status == "passed" else "",
            "status": status
        }

        # Categorize
        if any(x in code for x in ["PE", "ZY", "ZZ"]):
            categories["PE & Service"]["courses"].append(record)
        elif "GE" in code or "GEC" in code:
            categories["General Education"]["courses"].append(record)
        elif any(x in code for x in ["CS", "MATH", "PHYS", "EECS"]) and credits > 0:
            categories["Compulsory"]["courses"].append(record)
        else:
            categories["Electives"]["courses"].append(record)

    # --- 3. CALCULATE TOTALS ---
    cumulative_gpa = f"{(total_grade_points / total_gpa_credits):.2f}" if total_gpa_credits > 0 else "0.00"
    current_courses = sum(1 for cat in categories.values() for c in cat["courses"] if c["status"] == "inProgress")

    final_categories = []
    for cat_name, data in categories.items():
        earned = sum(c['credits'] for c in data['courses'] if c['status'] == 'passed')
        final_categories.append({
            "title": cat_name,
            "earnedCredits": earned,
            "requiredCredits": data['required'],
            "records": data['courses']
        })

    # Wrap it in a parent JSON object
    output_data = {
        "summary": {
            "cumulativeGpa": cumulative_gpa,
            "currentSemesterCourses": str(current_courses)
        },
        "categories": final_categories
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=4, ensure_ascii=False)
    print(f"Successfully generated: {output_path}")

if __name__ == "__main__":
    # Adjust path if needed
    parse_graduation_data('lib/api/grades.html', 'assets/graduation_data.json')