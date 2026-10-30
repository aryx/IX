(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Weather.mli *)

type kind = Clear | Partly | Overcast | Fog | Drizzle | Rain | Snow | Storm
type day = { date : string; code : int; high : float; low : float; rain : float }

type t = {
  time : string;
  temperature : float;
  code : int;
  wind : float;
  hours : (string * float) list;
  days : day list;
}

let url (base : string) (lat : float) (lon : float) : string =
  Printf.sprintf
    "%s/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,weather_code,wind_speed_10m&hourly=temperature_2m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum&forecast_days=7&forecast_hours=24&timezone=auto"
    base lat lon

let of_json (text : string) : t =
  try
    let j = Json.of_text text in
    let current = Json.member "current" j and hourly = Json.member "hourly" j and daily = Json.member "daily" j in
    let column (o : Json.t) (name : string) : Json.t list = Json.list (Json.member name o) in
    let floats (o : Json.t) (name : string) : float list = List.map Json.float (column o name) in
    let times (o : Json.t) : string list = List.map Json.string (column o "time") in
    let rec days (d : string list) (c : Json.t list) (h : float list) (l : float list) (r : float list) : day list =
      match (d, c, h, l, r) with
      | date :: d, code :: c, high :: h, low :: l, rain :: r ->
          { date; code = Json.int code; high; low; rain } :: days d c h l r
      | _ -> []
    in
    { time = Json.string (Json.member "time" current);
      temperature = Json.float (Json.member "temperature_2m" current);
      code = Json.int (Json.member "weather_code" current);
      wind = Json.float (Json.member "wind_speed_10m" current);
      hours = List.combine (times hourly) (floats hourly "temperature_2m");
      days =
        days (times daily) (column daily "weather_code") (floats daily "temperature_2m_max")
          (floats daily "temperature_2m_min") (floats daily "precipitation_sum") }
  with
  | Json.Error why -> failwith ("not a forecast: " ^ why)
  | Invalid_argument _ -> failwith "not a forecast: its columns differ"

let kind (code : int) : kind =
  if code = 0 || code = 1 then Clear
  else if code = 2 then Partly
  else if code = 3 then Overcast
  else if code = 45 || code = 48 then Fog
  else if code >= 51 && code <= 57 then Drizzle
  else if (code >= 61 && code <= 67) || (code >= 80 && code <= 82) then Rain
  else if (code >= 71 && code <= 77) || code = 85 || code = 86 then Snow
  else if code >= 95 then Storm
  else Overcast

let words (code : int) : string =
  match code with
  | 0 -> "clear"
  | 1 -> "mainly clear"
  | 2 -> "partly cloudy"
  | 3 -> "overcast"
  | 45 -> "fog"
  | 48 -> "freezing fog"
  | 51 | 53 | 55 -> "drizzle"
  | 56 | 57 -> "freezing drizzle"
  | 61 -> "slight rain"
  | 63 -> "rain"
  | 65 -> "heavy rain"
  | 66 | 67 -> "freezing rain"
  | 71 -> "slight snow"
  | 73 -> "snow"
  | 75 -> "heavy snow"
  | 77 -> "snow grains"
  | 80 | 81 -> "showers"
  | 82 -> "heavy showers"
  | 85 | 86 -> "snow showers"
  | 95 -> "thunderstorm"
  | 96 | 99 -> "thunderstorm, hail"
  | _ -> Printf.sprintf "code %d" code

let day_name (date : string) : string =
  match List.map int_of_string_opt (String.split_on_char '-' date) with
  | [ Some year; Some month; Some day ] ->
      let name = Civil.weekday_name (Civil.weekday (Civil.days_from_civil { year; month; day })) in
      Printf.sprintf "%s %d" (String.sub name 0 3) day
  | _ -> date

let degrees (t : float) : string =
  let whole = int_of_float (Float.round t) in
  Printf.sprintf "%d\xc2\xb0" whole

let lines (name : string) (f : t) : string list =
  [ name;
    Printf.sprintf "%s: %s, %s, wind %.0f km/h" f.time (degrees f.temperature) (words f.code) f.wind ]
  @ List.map
      (fun (d : day) ->
        let rain = if d.rain > 0. then Printf.sprintf ", %.1f mm" d.rain else "" in
        Printf.sprintf "%-7s %s to %s, %s%s" (day_name d.date) (degrees d.low) (degrees d.high) (words d.code) rain)
      f.days
  @ [ "Weather data by Open-Meteo.com (CC BY 4.0)" ]
