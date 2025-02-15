# dependencies
suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(dplyr)
  library(here)
  library(glue)
  library(qs)
  library(ggpubr)
})

# setup
dir <- glue("{here()}")
source(glue("{dir}/scripts/misc/paths.R"))
source(glue("{dir}/scripts/misc/BIN.R"))
stamp <- "stamp_3"
dir <- glue("{here()}")


# read cd
dir <- glue("{proj_dir}/data/{stamp}/processed/combined")
fl <- list.files(dir, full.names = T)
cd <- lapply(fl, qread)

# filter
columns_to_keep <- c("sample", "sum", "detected", "fov", "Area.um2", "label", "CenterX_global_px","CenterY_global_px")
cd <- lapply(cd, function(x) {
  x[, columns_to_keep, drop = FALSE]
})
cd <- do.call(rbind,cd)

#  General palette
pal <- Polychrome::createPalette(26,c("#99FFFF", "#FF99FF", "#FFFF99"))
val <- unique(cd$label)
names(pal) <- val

cd$sample <- recode(cd$sample, "c100" = "100 C", "c250" = "250 C", "c500" = "500 C", "c1000" = "1000 C",
                    "c20k" = "20K C", "n20k" = "20K N")


psamp <- Polychrome::createPalette(10, c("#a6dba0", "#c2a5cf", "#f4a582"))
names(psamp) <- unique(cd$sample)

cdfull <- cd
###### #### ###### #### ###### #### ###### #### ###### #### ###### #### ###### ##


#cd <- cd[!cd$sample %in% c("20K C", "20K N"), ]



# CELL position
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #
df <- cd

# Invert the levels of the sample factor
#df$sample <- factor(df$sample, levels = rev(levels(factor(df$sample))))
df$sample <- factor(df$sample, levels = c("20K C","20K N","1000 C","500 C","250 C","100 C"))
# Custom labels
# Plot
gg_pos <- ggplot(df, aes(x = CenterX_global_px, y = CenterY_global_px, color = sample)) + 
  ggrastr::rasterise(geom_point(shape = 16, size = 0.8), dpi = 800) +
  scale_color_manual(values = psamp) +
  theme_bw() + 
  scale_x_continuous(labels = scientific_10) +
  scale_y_continuous(labels = scientific_10) +
  labs(color = "Square", x = "x_px", y = "y_px") +
  guides(color = guide_legend(override.aes = list(size = 4)))

dir <- glue("{proj_dir}/figures/fig2/rds")
dir.create(dir, showWarnings = F)
saveRDS(gg_pos, file = glue("{dir}/gg_pos.rds"))

# CELL NUMBERS
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #######
cd$sample <- factor(cd$sample, levels = c("100 C","250 C","500 C","1000 C", "20K C", "20K N"))
df <- as.data.frame(table(cd$sample, cd$label)) %>%
  group_by(Var1) %>%
  mutate(Proportion = round((Freq / sum(Freq)) * 100, 2))

gg_cnumb <- ggplot(df, aes(x = Var1, y = Proportion)) + 
  geom_col(aes(fill = Var2), alpha = 0.9) +
  scale_fill_manual(values = pal) +
  theme_bw() +
  theme(text = element_text(size = 25, color = "black"),
        axis.text = element_text(size = 20, color = "black"),
        legend.position = "right",
        panel.grid = element_blank()) +
  labs(fill = "Cell Type", y = "Proportion") +
  labs(x = "Sample", fill = "Cell Type") 
gg_cnumb

saveRDS(gg_cnumb, file = glue("{dir}/gg_cnumb.rds"))
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #######

# CORRELATION OF CELL NUMBERS
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #######
df <- as.data.frame(table(cd$sample)) %>%
      mutate(InputCells = c(100,225,500,1000, 20000,20000))
avg <- round(mean(df$pct_diff),2)


df <- df %>%
  mutate(pct_diff = (round((Freq/InputCells),2))*100)


ggplot(df, aes(x = Var1, y = pct_diff, fill = Var1)) +
  geom_col() +
  scale_fill_manual(values = psamp) +
  geom_text(aes(label = Freq), vjust = -0.5, size = 2.5, color = "black") +
  theme_bw() + 
  theme(panel.grid = element_blank()) +
  labs(x = "sub-STAMP", y = "% recovered cells") + 
  theme(legend.position = "none", 
        text = element_text(size = 20, color = "black"),
        axis.text = element_text(size = 18, color = "black")) +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())








saveRDS(gg_corr, file = glue("{dir}/gg_corr.rds"))
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #######

# GENE COUNTS & Features
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #######
df <- cd
# plot function
create_boxplot <- function(df, var_name, title, ylab) {
  # Dynamically calculate the median for each sample and create labels
  labels <- setNames(
    lapply(unique(df$sample), function(sample) {
      median_value <- round(median(df[[var_name]][df$sample == sample]), 0)
      glue("{median_value}")
    }),
    unique(df$sample)
  )
  
  # Create the plot
  ggplot(df, aes(x = sample, y = !!sym(var_name), color = sample)) +
    geom_boxplot(aes(fill = sample), alpha = 0.1) + # Set alpha for fill only
    theme_bw() +
    theme(panel.grid = element_blank()) +
    scale_color_manual(values = psamp, labels = labels) +
    scale_fill_manual(values = psamp) +
    labs(color = title) +
    labs(y = ylab, color = "Median") +
    guides(fill = "none") 
}

gg_sum <- create_boxplot(df, "sum", "Sample", "nCount")
gg_feat <- create_boxplot(df, "detected", "Sample", "nFeature")
gg_area <- create_boxplot(df, "Area.um2", "Sample", "Area.um2")

gg_sum
gg_feat
gg_area

# Save
saveRDS(gg_sum, file = glue("{dir}/gg_sum.rds"))
saveRDS(gg_area, file = glue("{dir}/gg_area.rds"))
saveRDS(gg_feat, file = glue("{dir}/gg_feat.rds"))

####### ####### ####### ####### ####### ####### ####### ####### ####### ######## 
####### ####### ####### ####### ####### ####### ####### ####### ####### ########
######## ####### ####### ####### ## PART 2 ########### ####### ####### #########  
####### ####### ####### Visualization Cell/nuclei ####### ####### ####### ######
####### ####### ####### ####### ####### ####### ####### ####### ####### ########

# GEX correlation
####### ####### ####### ####### ####### ####### ####### ####### ####### ####### #######
res_dir <- glue("{proj_dir}/data/Stamp_3/processed/")
n <- qread(glue("{res_dir}/n20k/qc_n20k.qs"), nthreads = 8)
c <- qread(glue("{res_dir}/c20k/qc_c20k.qs"), nthreads = 8)

# Take count matrices
c <- as(counts(c), "dgCMatrix")
n <- as(counts(n), "dgCMatrix")

# norm by total n cells
c <- rowSums(c) / ncol(n)
n <- rowSums(n) / ncol(n)
c <- as.data.frame(as.matrix(c))
n <- as.data.frame(as.matrix(n))

names(c)[1] <- "Cells"
names(n)[1] <- "Nuclei"

c$gene <- rownames(c)
n$gene <- rownames(n)
df <- merge(c, n, by = "gene", all = TRUE)


gg_corr <- ggplot(df, aes(x = Cells, y = Nuclei)) + 
  ggrastr::rasterize(geom_point(shape = 16, size = 0.9, alpha = 0.8), dpi = 300) +
  ggpubr::stat_cor(method = "pearson", label.x = -3, label.y = 50, size = 5) + 
  geom_smooth(method = "lm", color = "red") +
  theme_bw() +
  theme(panel.grid =  element_blank()) +
  labs(x ="Mean counts/gene - 20K cells", y ="Mean counts/gene - 20K nuclei")


saveRDS(gg_corr, file = glue("{dir}/gg_gene_corr.rds"))
