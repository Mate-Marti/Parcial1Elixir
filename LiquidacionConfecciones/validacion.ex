defmodule Validacion do
  @moduledoc """
  Módulo de validación de lotes. Contiene las cinco reglas de validación.
  Cada regla es una función que devuelve `:ok` si el lote cumple la regla,
  o `{:error, motivo}` si no la cumple.
  """
  @dia_minimo 1
  @dia_maximo 6
  @prendas_minimas 1
  @prendas_maximas 180
  @defectos_minimo 0
  @defectos_maximo 100

  @doc """
  Valida un lote encadenando las cinco reglas con `with`.
  Devuelve `{:ok, lote}` o `{:error, motivo}` con el primer motivo encontrado.
  """
  def validar_lote(lote, confeccionistas, lineas) do
    with :ok <- validar_confeccionista(lote.confeccionista, confeccionistas),
         :ok <- validar_linea(lote.linea, lineas),
         :ok <- validar_dia(lote.dia),
         :ok <- validar_prendas(lote.prendas),
         :ok <- validar_defectos(lote.defectos) do
      {:ok, lote}
    end
  end

  @doc "Regla 1: el código del confeccionista debe existir en la lista."
  #Enum.any?()sirve para verificar si algún elemento de la lista cumple con la condición especificada en la función anónima y
  # Devuelve true si al menos un elemento cumple con la condición
  # y false en caso contrario,utilizamos patter maching para acceder a los valores de los mapas y compararlos con el valor
  # proporcionado
  #&1.codigo == confeccionista) verifica si el valor del campo codigo del mapa es igual al valor de la variable confeccionista

  def validar_confeccionista(codigo, confeccionistas) do
    if Enum.any?(confeccionistas, &(&1.codigo == codigo)) do
      :ok
    else
      {:error, :confeccionista_desconocido}
    end
  end

  @doc "Regla 2: el id de la línea debe existir en la lista."
  def validar_linea(id, lineas) do
    if Enum.any?(lineas, &(&1.id == id)) do
      :ok
    else
      {:error, :linea_desconocida}
    end
  end

  @doc "Regla 3: el día debe ser un entero entre 1 y 6."
  #si esta en el rango de 1 a 6, devuelve :ok, de lo contrario devuelve un error con el motivo :dia_invalido
  #is_integer(dia) verifica si el valor de dia es un número entero
  def validar_dia(dia) when is_integer(dia) and dia >= @dia_minimo and dia <= @dia_maximo,
    do: :ok

  def validar_dia(_dia), do: {:error, :dia_invalido}

  @doc "Regla 4: las prendas deben ser un entero entre 1 y 180."
  #si esta en el rango de 1 a 180, devuelve :ok, de lo contrario devuelve un error con el motivo :prendas_fuera_de_rango
  #is_integer(prendas) verifica si el valor de prendas es un número entero
  def validar_prendas(prendas)
      when is_integer(prendas) and prendas >= @prendas_minimas and prendas <= @prendas_maximas,
      do: :ok

  def validar_prendas(_prendas), do: {:error, :prendas_fuera_de_rango}

  @doc "Regla 5: el porcentaje de defectos debe ser un número entre 0 y 100."
  #si esta en el rango de 0 a 100, devuelve :ok, de lo contrario devuelve un error con el motivo :porcentaje_invalido
  def validar_defectos(defectos) do
    if is_number(defectos) and defectos >= 0 and defectos <= 100 do
      :ok
    else
      {:error, :porcentaje_invalido}
    end
  end
#recibe un lote, una lista de confeccionistas y una lista de lineas, y valida cada campo del lote utilizando las funciones de
#validación correspondientes
#valida todos los campos del lote y devuelve {:ok, lote} si todos son válidos, o {:error, motivo} si alguno es inválido
#utiliza with para encadenar las validaciones y devolver el primer error encontrado, si todas son válidas devuelve {:ok, lote}
  def validar_lote(lote, confeccionistas, lineas) do
    with :ok <- validar_confeccionista(lote.confeccionista, confeccionistas),
         :ok <- validar_linea(lote.linea, lineas),
         :ok <- validar_dia(lote.dia),
         :ok <- validar_prendas(lote.prendas),
         :ok <- validar_defectos(lote.defectos) do

      {:ok, lote}
    else
      {:error, motivo} -> {:error, motivo}
    end
  end

end
