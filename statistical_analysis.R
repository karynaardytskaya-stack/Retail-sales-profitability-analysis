# ==============================================================================
# Retail Sales & Profitability Statistical Analysis (2022–2024)
# Author: Karyna Ardytskaya
# Dataset: v_clean_sales_summy.csv (26,385 retail transactions)
# ==============================================================================

library(dplyr)
library(ggplot2)
library(RColorBrewer)



dane$category <- as.factor(dane$category)
dane$sales_channel <- as.factor(dane$sales_channel)
dane$weekend <- as.factor(dane$weekend)
dane$discount_pct <- factor(paste0(round(dane$discount * 100),"%"),
                            levels=c("0%","5%","10%","15%","20%",
            "25%","30%","40%"),
            ordered=TRUE)

dane$profit_margin <- (dane$net_profit/dane$gross_sales)*100

str(dane)


##Do higher discounts actually motivate customers to buy larger quantities, 
##or do they simply erode profit margins into negative territory?

cor_test <- cor.test(dane$discount, dane$quantity)
print(cor_test)

model_profit <- lm(net_profit ~ discount + quantity + category,data=dane)
summary(model_profit)


##Visualization: Profit Distribution by Discount Tier (Highlighting the 40% Loss Zone)
dane$is_toxic_discount <- ifelse(dane$discount >= 0.40, "Loss Zone (40%)", 
                                 "Profitable Tiers (0-30%)")

p1 <- ggplot(dane, aes(x=discount_pct, y=net_profit, fill = is_toxic_discount))+
  geom_boxplot(outlier.alpha = 0.15) +
  geom_hline(yintercept=0, linetype = "dashed", color = "darkred", linewidth=1)+
  scale_fill_manual(values = c("Loss Zone (40%)"= "#E74C3C", "Profitable 
                    Tiers (0-30%)"= "#5DADE2")) + coord_cartesian(ylim = c(-150,250))+
  theme_bw()+labs(title = "Net Profit Distribution Across Discount Levels",
                  subtitle = "Median profit drops below 0 at the 40% 
                  discount threshold (dashed red line)",
x="Discount Tier",
y = "Net Profit per Transaction ($)",
fill = "Profitability Status") +
  theme(legend.position = "top")

print(p1)
ggsave("01_discount_profit_boxplot.png", plot = p1, width = 22, height = 14,
       units = "cm")


##Is there a statistically significant difference in average order revenue 
##        and net profit margin between Online and In-Store channels?


channel_summary <- dane %>%
  group_by (sales_channel) %>%
  summarise(
    order_count = n(),
    mean_sales = round(mean(net_sales,na.rm=TRUE),2),
    median_sales = round(median(net_sales, na.rm=TRUE),2),
    mean_profit = round(mean(net_profit, na.rm =TRUE),2),
    mean_margin_pct = round(mean(profit_margin, na.rm=TRUE),2)
)
print(channel_summary)


t_test_sales <- t.test(net_sales ~ sales_channel, data=dane)
print(t_test_sales)


wilcox_sales <- wilcox.test(net_sales ~ sales_channel, data=dane)
print(wilcox_sales)


t_test_margin <- t.test(profit_margin ~ sales_channel, data=dane) 
print(t_test_margin)


##Visualization: Net Profit Margin Comparison by Channel & Category

p2 <- ggplot(dane, aes(x=category, y=net_profit, fill=sales_channel))+
  geom_boxplot(outlier.alpha = 0.15)+
  geom_hline(yintercept=0, linetype = "dotted", color = "black")+
  scale_fill_brewer(palette="Set2")+
  coord_cartesian(ylim=c(-100,200))+
  theme_bw()+
  labs(
    title = "Net Profit Comparison: Online vs. In-Store by Category",
    x="Product Category",
    y="Net Profit ($)",
    fill = "Sales Channel"
  )+
  theme(legend.position = "top")

print(p2)
ggsave("02_channel_profit_comparison.png",plot=p2,width=20,
       height=14, units="cm")


##Do average daily sales differ significantly between Weekdays and Weekends?


daily_sales <- dane%>%
  group_by (order_date, weekend, year) %>%
  summarise(
    daily_orders = n(),
    daily_revenue = sum(net_sales,na.rm = TRUE),
    daily_profit = sum(net_profit, na.rm = TRUE),
    .groups="drop"
  )


weekend_summary <- daily_sales %>%
  group_by(weekend) %>%
  summarise(
    days_count=n(),
    avg_daily_orders   = round(mean(daily_orders), 1),
    avg_daily_revenue  = round(mean(daily_revenue), 2),
    median_daily_rev   = round(median(daily_revenue), 2),
    avg_daily_profit   = round(mean(daily_profit), 2)
  )
print(weekend_summary)


t_test_weekend <- t.test(daily_revenue ~ weekend, data=daily_sales)
print(t_test_weekend)


##Visualization: Distribution of Daily Revenue (Weekday vs. Weekend)

p3 <- ggplot(daily_sales, aes(x=daily_revenue, fill=weekend))+
  geom_histogram(data = subset(daily_sales, weekend=="Weekday"),
                 alpha=0.5,bins=25)+
  geom_histogram(data=subset(daily_sales,weekend=="Weekend"), alpha=0.6,
                 bins=25)+
  scale_fill_manual(values = c("Weekday"= "#7F8C8D", "Weekend"="#27AE60")) +
  theme_bw()+
  labs(
    title ="Daily Net Revenue Distribution: Weekdays vs. Weekends",
    subtitle = "Comparing total daily store & online revenue across 1,096 calendar days",
    x = "Daily Net Revenue ($)",
    y = "Number of Days",
    fill = "Day Type"
  ) +
  theme(legend.position = "top")
  
print(p3)
ggsave("03_daily_revenue_weekend_vs_weekday.png", plot = p3, width = 20, height = 14, units = "cm")


















