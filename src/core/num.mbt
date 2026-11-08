// 数值解析：十进制用「整数尾数 / 10 的幂」一次算完，避免逐位除 10 累积误差。

///|
fn pow10(n : Int32) -> Double {
  let mut value = 1.0
  let mut k = 0
  while k < n {
    value = value * 10.0
    k = k + 1
  }
  value
}

///|
fn digit_value(digit : Int32) -> Double {
  match digit {
    0 => 0.0
    1 => 1.0
    2 => 2.0
    3 => 3.0
    4 => 4.0
    5 => 5.0
    6 => 6.0
    7 => 7.0
    8 => 8.0
    _ => 9.0
  }
}

///|
pub fn parse_double(text : String) -> Double? {
  let data = @utf8.encode(text)
  let n = data.length()
  let mut i = 0
  let mut negative = false
  if i < n && (data[i] == b'-' || data[i] == b'+') {
    negative = data[i] == b'-'
    i = i + 1
  }
  let mut mantissa = 0.0
  let mut seen = false
  while i < n && dec_digit(data[i]) >= 0 {
    mantissa = mantissa * 10.0 + digit_value(dec_digit(data[i]))
    seen = true
    i = i + 1
  }
  let mut fraction = 0
  if i < n && data[i] == b'.' {
    i = i + 1
    while i < n && dec_digit(data[i]) >= 0 {
      mantissa = mantissa * 10.0 + digit_value(dec_digit(data[i]))
      fraction = fraction + 1
      seen = true
      i = i + 1
    }
  }
  if !seen {
    return None
  }
  let mut exponent = 0
  if i < n && (data[i] == b'e' || data[i] == b'E') {
    i = i + 1
    let mut exp_negative = false
    if i < n && (data[i] == b'-' || data[i] == b'+') {
      exp_negative = data[i] == b'-'
      i = i + 1
    }
    let mut value = 0
    let mut digits = 0
    while i < n && dec_digit(data[i]) >= 0 {
      value = value * 10 + dec_digit(data[i])
      digits = digits + 1
      i = i + 1
    }
    if digits == 0 {
      return None
    }
    exponent = if exp_negative { -value } else { value }
  }
  if i != n {
    return None
  }
  // 单次除法 / 乘法而不是逐位缩放，避免多次舍入把结果推离最近的双精度值。
  let mut value = mantissa
  if fraction > 0 {
    let scale = pow10(fraction)
    value = value / scale
  }
  if exponent != 0 {
    let scale = pow10(if exponent < 0 { -exponent } else { exponent })
    if exponent > 0 {
      value = value * scale
    } else {
      value = value / scale
    }
  }
  Some(if negative { -value } else { value })
}

///|
pub fn hex_digit(b : Byte) -> Int32 {
  let v = b.to_int()
  if v >= 48 && v <= 57 {
    v - 48
  } else if v >= 97 && v <= 102 {
    v - 87
  } else if v >= 65 && v <= 70 {
    v - 55
  } else {
    -1
  }
}

///|
pub fn dec_digit(b : Byte) -> Int32 {
  let v = b.to_int()
  if v >= 48 && v <= 57 {
    v - 48
  } else {
    -1
  }
}
