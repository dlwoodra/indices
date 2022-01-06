function calc_f10_moving_avg, daily, width_in_days=width_in_days

  if size(width_in_days,/type) eq 0 then width_in_days = 81

  ; calculate 81-day mean, centered on each day
  ; to avoid search the whole large array, look over close ranges only
  halfwidth = width_in_days / 2L
  for i=0L,n_elements(daily)-1 do begin

     loidx = (i - halfwidth) > 0L ; no negative indices allowed
     hiidx = ( i + halfwidth ) < (n_elements(daily)-1) ; no future indices allowed
     ; this means the last 41 days will always be changing as new data are added
     idx=where( abs(daily[i].jd - daily[loidx:hiidx].jd) lt halfwidth, n_idx )
     daily[i].f10a = mean( daily[idx + loidx].f10, /nan )
  endfor

  return, daily
end
