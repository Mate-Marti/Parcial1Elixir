defmodule Validaciones do
  #Enum.any?()sirve para verificar si algún elemento de la lista cumple con la condición especificada en la función anónima y
  # Devuelve true si al menos un elemento cumple con la condición
  # y false en caso contrario,utilizamos patter maching para acceder a los valores de los mapas y compararlos con el valor proporcionado
  #&1.codigo == confeccionista) verifica si el valor del campo codigo del mapa es igual al valor de la variable confeccionista
  def validar_confeccionista(confeccionista, confeccionistas) do
      if Enum.any?(confeccionistas, &(&1.codigo == confeccionista)) do
      :ok
    else
      {:error, :confeccionista_desconocido}
    end
  end
  def validar_linea(linea, lineas) do
  if Enum.any?(lineas, &(&1.id == linea)) do
      :ok
    else
      {:error, :linea_desconocida}
    end
  end
  #si esta en el rango de 1 a 6, devuelve :ok, de lo contrario devuelve un error con el motivo :dia_invalido
  def validar_dia(dia) do
if Enum.any?(1..6,&(&1 == dia)) do
      :ok
    else
      {:error, :dia_invalido}
    end
  end
  #si esta en el rango de 1 a 180, devuelve :ok, de lo contrario devuelve un error con el motivo :prendas_fuera_de_rango
  def validar_prendas(prendas) do
if Enum.any?(1..180, &(&1 == prendas)) do
      :ok
    else
      {:error, :prendas_fuera_de_rango}
    end
  end
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
