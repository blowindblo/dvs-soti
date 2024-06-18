library(packcircles)

plot_data_r <- final_data %>% 
  filter(ToolsForDV_R=='R') %>% 
  group_by(inspiration,type) %>% 
  summarise(count = n()) 

points <- 45
packing <- circleProgressiveLayout(plot_data_r$count) %>% 
  mutate(inspiration = plot_data_r$inspiration,
         type = plot_data_r$type,
         id = row_number(),
         count = plot_data_r$count)
dat.gg <- circleLayoutVertices(packing, npoints = points) %>% 
  inner_join(packing %>% select(id, type, inspiration, count), by = 'id')
dat.gg$type <- rep(data$type, each= points + 1)

ggplot() +
  geom_polygon(data = dat.gg, aes(x, y, group=id, fill = type)) +
  geom_text(data = packing, aes(x, y, size = count, label = inspiration)) +
  theme_void() +
  theme(legend.position="none") +
  coord_equal()


rescale()