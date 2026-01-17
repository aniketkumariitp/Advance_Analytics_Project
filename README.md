# 📊 Advanced Customer & Product Analytics using SQL

Welcome to an advanced SQL project that extracts powerful insights from sales data.  
This project focuses on real-world **business intelligence** techniques for deriving **actionable analytics** using only SQL.

---
## 📘 Live Documentation

🔗 **Live Documentation:** https://aniketkumariitp.github.io/Advance_Analytics_Project/

## 🎯 Project Goal

The aim is to simulate **real-life analytics tasks** using SQL that companies use for making strategic decisions.  
It focuses on **six core analytical areas**:

### 🔍 Types of Analysis Performed:

- ✅ **Cumulative Analysis**  
  → Total orders, total revenue, total quantity over time

- ✅ **Performance Analysis**  
  → Product-level and customer-level performance KPIs

- ✅ **Part-to-Whole Proportional**  
  → Contribution of product categories, customer segments to total sales

- ✅ **Change-Over-Time Trends**  
  → Sales behavior across months and years

- ✅ **Reporting**  
  → Customer and product summaries for dashboard integration

- ✅ **Data Segmentation**  
  → Customers: VIP, Regular, New  
  → Products: High, Medium, Low performers

---

## 📂 Project Structure

### 📄 1. `report_customers.sql`
- KPIs: Sales, Orders, Quantity, Recency, Lifespan
- Segments: VIP / Regular / New
- Age Group Bucketing
- Uses `DATEDIFF`, `PERIOD_DIFF`, `YEAR_MONTH`

### 📄 2. `report_products.sql`
- KPIs: Orders, Revenue, Monthly Revenue, Recency
- Segments: High / Medium / Low performers
- Product lifespan and order frequency

---

## 📈 Screenshot Preview

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/ee537161-34e8-49ee-b5f9-f9a7522a0c23" />
---

## What I Learn

- Modular SQL with Common Table Expressions (CTEs)
- Behavioral segmentation logic using `CASE WHEN`
- Time-based analytics using `DATEDIFF`, `YEAR(order_date)`
- Revenue trends and proportional analysis
- Customer and product scoring techniques

---

## 💻 Tech Stack

- SQL (MySQL or any compatible engine)
- Tools used: VS Code / DBeaver / MySQL Workbench

---

## 🧾 How to Use

1. Clone this repository  
2. Import your own tables (`fact_sales`, `dim_customers`, `dim_products`)  
3. Run the SQL files individually in your SQL client  
4. Use the output for visualization in Power BI, Excel, or Tableau

---

## 📊 Sample KPI Output (Customer Level)

| Metric                 | Value      |
|------------------------|------------|
| Total Customers        | 900        |
| VIP Customers          | 120        |
| Average Monthly Spend  | ₹1,250     |
| Most Active Age Group  | 25–35      |

---

## 👤 Author

**Aniket Kumar**  
📎 [www.linkedin.com/in/aniket-kumar-995424324](https://www.linkedin.com/in/aniket-kumar-995424324)

---

## 🌟 Show Support

If you liked this project, consider starring ⭐ this repo and sharing it with fellow SQL learners.
