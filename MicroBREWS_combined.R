analyze_movie_signals <- function(which = c("s2", "s3")) {
  which <- match.arg(which)
  
  # libraries
  require(zoo)
  require(ggplot2)
  require(pracma)
  
  if (which == "s2") {
    # ---- Load data ----
    df <- read.csv("/Users/yyc2wf/Downloads/Movie_S2_results/signals_Movie_S2.csv")
    
    # ---- Rolling average of signal ----
    df$avg_signal <- rollmean(df$signal, k = 5, fill = df$signal)
    
    # ---- Normalized signal (relative to frame 1) ----
    # assuming 'frame' is numeric; if it's character, as.numeric() it
    df$norm_signal <- df$avg_signal / df$avg_signal[df$frame == 1]
    
    # ---- Plots (optional, but kept from your script) ----
    ggplot(df, aes(x = frame, y = avg_signal)) +
      geom_point() + geom_line()
    
    ggplot(df, aes(x = frame, y = norm_signal)) +
      geom_point() + geom_line() + theme_bw()
    
    # ---- Peaks for S2 (on norm_signal) ----
    peaks <- findpeaks(df$norm_signal,
                       nups = 4,
                       ndowns = 1,
                       minpeakheight = 1.1)
    
  } else if (which == "s3") {
    # ---- Load data ----
    df <- read.csv("/Users/yyc2wf/Downloads/Movie_S3_results/signals_Movie_S3.csv")
    
    # ---- Rolling average of signal ----
    df$avg_signal <- rollmean(df$signal, k = 5, fill = df$signal)
    
    # ---- Normalized signal (relative to frame 1) ----
    df$norm_signal <- df$avg_signal / df$avg_signal[df$frame == 1]
    
    # ---- Basic plots (kept from your script) ----
    ggplot(df, aes(x = frame, y = norm_signal)) +
      geom_point() + geom_line() + theme_bw()
    
    ggplot(df, aes(x = frame, y = area)) +
      geom_point() + geom_line() + theme_bw()
    
    # ---- Area normalization + area-corrected signal (your S3 logic) ----
    df$norm_area          <- df$area / median(df$area)
    df$norm_signalbyarea  <- df$norm_signal / df$norm_area
    df$avg_areasignal     <- rollmean(df$norm_signalbyarea,
                                      k = 5,
                                      fill = df$norm_signalbyarea)
    df$avg_areasignal_norm <- df$avg_areasignal /
      df$avg_areasignal[df$frame == 1]
    
    ggplot(df, aes(x = frame, y = avg_areasignal_norm)) +
      geom_point() + geom_line() + theme_bw()
    
    # ---- Peaks for S3 (on avg_areasignal_norm) ----
    peaks <- findpeaks(df$avg_areasignal_norm,
                       nups = 4,
                       ndowns = 2,
                       minpeakheight = 1.1)
  }
  
  # Return both the processed data and the peaks
  return(list(
    which = which,
    data  = df,
    peaks = peaks
  ))
}
