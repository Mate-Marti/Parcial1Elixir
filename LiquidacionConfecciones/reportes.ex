defmodule Reportes do
  @meta_diaria 600
  @dias 1..6
  @minimo_lotes_calidad 3
  @motivos [
    :confeccionista_desconocido,
    :linea_desconocida,
    :dia_invalido,
    :prendas_fuera_de_rango,
    :porcentaje_invalido
  ]

  # R1. Rechazos
  @doc """
  contar_rechazos/1 recibe una lista de lotes rechazados y devuelve un mapa con la cantidad de rechazos por motivo.
  Devuelve `[{motivo, cantidad}]` con los cinco motivos en el orden de las
  reglas, incluso los que tienen cero rechazos.
  enum.frequencies/1 cuenta la frecuencia de cada motivo en la lista de rechazados,
  devolviendo un mapa con los motivos como claves y las cantidades como valores
  """
  def contar_rechazos(rechazados) do
    frecuencias = rechazados |> Enum.map(fn {_lote, motivo} -> motivo end) |> Enum.frequencies()
    Enum.map(@motivos, fn motivo -> {motivo, Map.get(frecuencias, motivo, 0)} end)
  end

  # Devuelve los lotes rechazados junto con el texto del motivo
  def lotes_rechazados(lotes, confeccionistas, lineas) do
    motivos = %{
      :confeccionista_desconocido => "Confeccionista desconocido",
      :linea_desconocida => "Línea desconocida",
      :dia_invalido => "Día inválido",
      :prendas_fuera_de_rango => "Prendas fuera de rango",
      :porcentaje_invalido => "Porcentaje de defectos inválido"
    }

    lotes
    |> Enum.map(fn lote ->
      case Validaciones.validar_lote(lote, confeccionistas, lineas) do
        {:ok, _} ->
          nil

        {:error, motivo} ->
          # Buscamos el texto correspondiente al motivo del rechazo en el mapa de motivos
          motivo_texto = Map.get(motivos, motivo, motivo)
          {lote, motivo_texto}
      end
    end)
    # el enum.reject/2 filtra los elementos nulos de la lista resultante,
    # dejando solo los lotes rechazados con su motivo correspondiente
    |> Enum.reject(&is_nil/1)
  end

  # Funcion auxiliar Privada
  defp sumar_prendas_por(lotes, clave) do
    Enum.reduce(lotes, %{}, fn lote, acumulado ->
      Map.update(acumulado, clave.(lote), lote.prendas, &(&1 + lote.prendas))
    end)
  end

  @doc """
  reporte 1
  Esta función recibe una lista de lotes, una lista de confeccionistas y una lista de líneas, y
  genera un reporte de los lotes rechazados, agrupándolos por motivo de rechazo
  y mostrando la cantidad de lotes rechazados por cada motivo.
  """
  def r1(lotes, confeccionistas, lineas) do
    rechazos =
      lotes
      |> lotes_rechazados(confeccionistas, lineas)
      |> Enum.group_by(fn {_lote, motivo} -> motivo end, fn {lote, _} -> lote end)
      |> Enum.map(fn {motivo, lista_lotes} ->
        %{
          motivo: motivo,
          cantidad: length(lista_lotes),
          lotes: lista_lotes
        }
      end)

    IO.inspect(rechazos, label: "Lotes rechazados por motivo y su cantidad", limit: :infinity)
  end

  # Reporte 4
  # recibe lotes válidos y líneas, devuelve una lista de mapas con id, nombre, prendas, productividad de cada línea, ordenadas de mayor a menor productividad. Las líneas sin lotes válidos aparecen con cero.
  # enum.map/2 itera sobre cada línea en la lista de líneas, y para cada línea l,
  # obtiene la cantidad de prendas producidas en esa línea a partir de los lotes válidos,
  # y calcula la productividad dividiendo las prendas por los puestos de la línea
  # sort_by/3 ordena la lista de resultados por el campo :productividad en orden descendente, de mayor a menor productividad
  @doc """
  R2. Productividad por línea
  """
  def productividad_lineas(lotes_validos, lineas) do
    prendas_por_linea = sumar_prendas_por(lotes_validos, & &1.linea)

    lineas
    |> Enum.map(fn linea ->
      prendas = Map.get(prendas_por_linea, linea.id, 0)
      %{id: linea.id, nombre: linea.nombre, prendas: prendas, productividad: prendas / linea.puestos}
    end)
    |> Enum.sort_by(& &1.productividad, :desc)
  end

  # Reporte 3
  @doc "Prendas producidas en cada uno de los 6 días (cero si no hubo lotes)."
  # recibe lotes válidos y devuelve un mapa con la producción diaria (días 1 a 6)
  # sumar_prendas_por/2 acumula las prendas de los lotes válidos por día
  # enum.map/2 recorre el rango de días y arma una tupla {dia, prendas} por cada uno, con Map.get/3
  # obteniendo la cantidad de prendas del día desde el mapa de prendas por día,
  # usando 0 como valor por defecto si ese día no tuvo lotes
  # enum.into/2 convierte esa lista de tuplas en un mapa
  def produccion_diaria(lotes_validos) do
    prendas_por_dia = sumar_prendas_por(lotes_validos, & &1.dia)

    @dias
    |> Enum.map(fn dia -> {dia, Map.get(prendas_por_dia, dia, 0)} end)
    |> Enum.into(%{})
  end

  def meta_cumplida?(prendas), do: prendas >= @meta_diaria

  @doc "Resume si la meta se cumplió todos los días y si se cumplió al menos uno."
  # enum.all?/2 verifica si todos los días cumplieron la meta
  # enum.any?/2 verifica si al menos un día cumplió la meta
  # cada elemento del mapa llega como tupla {dia, prendas}
  def resumen_meta(produccion) do
    %{
      todos: Enum.all?(produccion, fn {_dia, prendas} -> meta_cumplida?(prendas) end),
      alguno: Enum.any?(produccion, fn {_dia, prendas} -> meta_cumplida?(prendas) end)
    }
  end

  # Reporte 4
  @doc """
  Liquidación de todos los confeccionistas, numerada y ordenada por pago neto de
  mayor a menor. Debe mostrar el numero de prendas, valor de lotes, bonificaciones, alquiler y neto con el cual se renquea los confeccionistas.
  Los valores monetarios se imprimen con dos decimales y sin notación científica
  """
  def ordenar_liquidaciones(lotes, confeccionistas, lineas) do

    lotes_validos =
    Enum.filter(lotes, fn lote ->
      case Validaciones.validar_lote(lote, confeccionistas, lineas) do
        {:ok, _} -> true
        {:error, _} -> false
      end
    end)

    liquidaciones =
    confeccionistas
    |> Enum.map(fn confeccionista ->
      liq = Liquidacion.liquidar_confeccionista(confeccionista, lotes_validos)
      total_prendas = Enum.reduce(liq.lotes_detalle, 0, fn lote, acc -> acc + lote.prendas end)

      Map.put(liq, :prendas, total_prendas)
    end)
    # 3. Ordenamos de mayor a menor pago neto
    |> Enum.sort_by(& &1.neto, :desc)

    liquidaciones
    |> Enum.with_index(1)
    |> Enum.each(fn {liq, idx} ->
      nombre = String.pad_trailing(liq.confeccionista.nombre, 18)
      prendas = String.pad_leading(to_string(liq.prendas), 6)
      bonificacion = Util.formatear_dinero(liq.bonificaciones)
      alquiler = Util.formatear_dinero(liq.descuento_alquiler)
      neto = Util.formatear_dinero(liq.neto)

    IO.puts("puesto:#{idx} nombre: #{nombre} N° prendas: #{prendas} valor bonificacion: $#{bonificacion} valor alquiler:$#{alquiler} valor neto:$#{neto}")
  end)
  liquidaciones

  end


  @doc """
  Reporte 5. Líderes por día
  """
  def lideres_por_dia(lotes_validos, confeccionistas) do
    nombres =
      confeccionistas
      |> Enum.map(fn c -> {c.codigo, c.nombre} end)
      |> Enum.into(%{})

    Enum.map(@dias, fn dia ->
      prendas_por_confeccionista =
        lotes_validos
        |> Enum.filter(&(&1.dia == dia))
        |> sumar_prendas_por(& &1.confeccionista)

      lideres_del_dia(dia, prendas_por_confeccionista, nombres)
    end)
  end

  # Ordena de mayor a menor con Enum.sort/2, igual que en ranking.
  # El case separa el día sin lotes ([]) del caso normal, donde la cabeza de la lista es el líder.
  # for con filtro agrega a los empatados.
  defp lideres_del_dia(dia, prendas_por_confeccionista, nombres) do
    ordenados =
      Enum.sort(prendas_por_confeccionista, fn {_c1, p1}, {_c2, p2} -> p1 >= p2 end)

    case ordenados do
      [] ->
        %{dia: dia, prendas: 0, lideres: []}

      [{_codigo, maximo} | _resto] ->
        lideres =
          for {codigo, prendas} <- ordenados, prendas == maximo do
            Map.get(nombres, codigo)
          end

        %{dia: dia, prendas: maximo, lideres: Enum.sort(lideres)}
    end
  end

  # Junta todos los líderes de los seis días en una lista con Enum.reduce y ++.
  # Enum.group_by agrupa los nombres repetidos y length cuenta los días de cada uno.
  # Se ordena igual que arriba, y el case devuelve {0, []} si no hubo líderes.
  def mas_dias_en_primer_lugar(lideres_por_dia) do
    nombres = Enum.reduce(lideres_por_dia, [], fn dia, acc -> acc ++ dia.lideres end)

    ordenados =
      nombres
      |> Enum.group_by(fn nombre -> nombre end)
      |> Enum.map(fn {nombre, apariciones} -> {nombre, length(apariciones)} end)
      |> Enum.sort(fn {_n1, d1}, {_n2, d2} -> d1 >= d2 end)

    case ordenados do
      [] ->
        {0, []}

      [{_nombre, maximo} | _resto] ->
        {maximo, Enum.sort(for({nombre, dias} <- ordenados, dias == maximo, do: nombre))}
    end
  end

  # Reporte 6. Mejor calidad

  @doc """
  Porcentaje de defectos ponderado por prendas: suma(defectos × prendas) / suma(prendas).
  enum.reduce/3 acumula la suma de las prendas y la suma de defectos × prendas de cada lote
  """
  def mejor_calidad(lotes, confeccionistas, lineas) do

  lotes_validos =
    Enum.filter(lotes, fn lote ->
      case Validaciones.validar_lote(lote, confeccionistas, lineas) do
        {:ok, _} -> true
        {:error, _} -> false
      end
    end)

    resultados =
    confeccionistas
    |> Enum.map(fn confeccionista ->
      lotes_del_confeccionista =
        Enum.filter(lotes_validos, fn lote ->
          lote.confeccionista == confeccionista.codigo
        end)

      cantidad_de_lotes = length(lotes_del_confeccionista)

      if cantidad_de_lotes >= 3 do
        # Sumatoria de prendas defectuosas y total de prendas confeccionadas
        {prendas_defectuosas_totales, total_de_prendas} =
          Enum.reduce(
            lotes_del_confeccionista,
            {0.0, 0},
            fn lote, {acumulador_defectos, acumulador_prendas} ->
              prendas_defectuosas_del_lote = lote.prendas * (lote.defectos / 100.0)

              {
                acumulador_defectos + prendas_defectuosas_del_lote,
                acumulador_prendas + lote.prendas
              }
            end
          )

        porcentaje_ponderado =
          if total_de_prendas > 0 do
            (prendas_defectuosas_totales / total_de_prendas) * 100.0
          else
            0.0
          end

        %{
          nombre: confeccionista.nombre,
          lotes: cantidad_de_lotes,
          total_prendas: total_de_prendas,
          porcentaje_ponderado: porcentaje_ponderado
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn resultado -> resultado.porcentaje_ponderado end)


    IO.puts("\n Confeccionista con mejor calidad:")

  case resultados do
    [] ->
      IO.puts("No hay confeccionistas que cumplan con el criterio de tener al menos 3 lotes válidos.")

    [confeccionista_ganador | _] ->
      porcentaje_ganador_formateado = Util.formatear_dinero(confeccionista_ganador.porcentaje_ponderado)

      IO.puts("El confeccionista con mejor calidad es #{confeccionista_ganador.nombre}, alcanzando el menor porcentaje")
      IO.puts("de defectos ponderado con un #{porcentaje_ganador_formateado}% sobre un total de #{confeccionista_ganador.total_prendas} prendas")
      IO.puts("registradas en #{confeccionista_ganador.lotes} lotes válidos.\n")

      IO.puts("Desempeño general de los confeccionistas evaluados (mínimo 3 lotes):")

      Enum.each(resultados, fn elemento ->
        porcentaje_formateado = Util.formatear_dinero(elemento.porcentaje_ponderado)
        IO.puts("• #{String.pad_trailing(elemento.nombre, 22)} -> #{porcentaje_formateado}% defectos ponderados (#{elemento.lotes} lotes, #{elemento.total_prendas} prendas)")
      end)
  end

end


  @doc """
  Reporte 7. Costo total
  """
  def resumen_financiero_semanal(lotes, confeccionistas, lineas) do
    # 1. Filtrar los lotes válidos utilizando Validaciones.validar_lote/3
    lotes_validos =
      Enum.filter(lotes, fn lote ->
        case Validaciones.validar_lote(lote, confeccionistas, lineas) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)

    # Calcular el total pagado a los confeccionistas sumando el neto de cada liquidación
    total_pagado_taller =
      confeccionistas
      |> Enum.map(fn confeccionista ->
        liquidacion = Liquidacion.liquidar_confeccionista(confeccionista, lotes_validos)
        liquidacion.neto
      end)
      |> Enum.sum()

    # Calcular el total de prendas válidas sumando las prendas válidas de cada lote
    total_prendas_validas =
      Enum.reduce(lotes_validos, 0.0, fn lote, acumulador_prendas ->
        prendas_defectuosas = lote.prendas * (lote.defectos / 100.0)
        prendas_validas = lote.prendas - prendas_defectuosas
        acumulador_prendas + prendas_validas
      end)

    # Imprimir el resumen financiero y el costo promedio por prenda válida
    IO.puts("\nResumen financiero semanal:")

    total_pagado_formateado = Util.formatear_dinero(total_pagado_taller)

    IO.puts("Durante la presente semana, el taller debe pagar un valor total de")
    IO.puts("$#{total_pagado_formateado} por concepto de liquidaciones de confección.\n")

    if total_prendas_validas > 0 do
      costo_promedio_por_prenda = total_pagado_taller / total_prendas_validas
      costo_promedio_formateado = Util.formatear_dinero(costo_promedio_por_prenda)

      IO.puts("El costo promedio pagado por cada prenda válida fabricada es de")
      IO.puts("$#{costo_promedio_formateado} (calculado sobre un total de #{Util.formatear_dinero(total_prendas_validas)} prendas válidas).")
    else
      IO.puts("No se registraron prendas válidas durante la semana, por lo cual")
      IO.puts("el costo promedio por prenda no puede calcularse.")
    end

  end


  # Reporte 8. Confeccionistas en todas las líneas
  @doc "en la precente funcion se filtran los lotes validos, luego se busca a los confeccionistas
   que hayan trabajado en todas las lineas de produccion, y finalmente se imprime el resultado en la consola."

 def en_todas_las_lineas(lotes, confeccionistas, lineas) do
    #  Filtrar los lotes válidos utilizando Validaciones.validar_lote/3
    lotes_validos =
      Enum.filter(lotes, fn lote ->
        case Validaciones.validar_lote(lote, confeccionistas, lineas) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)

    # Identificar los confeccionistas que hayan trabajado en todas las líneas de producción
    cumplen_criterio =
      Enum.filter(confeccionistas, fn confeccionista ->
        Enum.all?(lineas, fn linea ->
          Enum.any?(lotes_validos, fn lote ->
            lote.confeccionista == confeccionista.codigo and lote.linea == linea.id
          end)
        end)
      end)

    # Imprimir el resultado en la consola
    IO.puts("\nConfeccionistas que trabajaron en todas las líneas de producción esta semana ")

    case cumplen_criterio do
      [] ->
        IO.puts("Ningún confeccionista elaboró lotes válidos en la totalidad de las líneas de producción esta semana.")

      lista ->
        IO.puts("Los siguientes confeccionistas elaboraron al menos un lote válido en todas las líneas de producción:\n")
        Enum.each(lista, fn c ->
          IO.puts(" • #{c.nombre} (Código: #{c.codigo})")
        end)
    end

    # Devolver la lista de nombres de los confeccionistas que cumplen el criterio
    Enum.map(cumplen_criterio, & &1.nombre)
  end

  @doc """
  Funcion para llamar todos los reportes
  """
  def todos_los_reportes(lotes, confeccionistas, lineas) do
    IO.puts("\nReporte 1: Lotes rechazados por motivo y su cantidad")
    r1(lotes, confeccionistas, lineas)
    IO.puts("\n")

    IO.puts("Reporte 2: Productividad por línea")
    IO.inspect(productividad_lineas(lotes, lineas), label: "Productividad por línea", limit: :infinity)
    IO.puts("\n")

    IO.puts("Reporte 3: Producción diaria")
    produccion_diaria = produccion_diaria(lotes)
    IO.inspect(produccion_diaria, label: "Producción diaria", limit: :infinity)
    IO.inspect(resumen_meta(produccion_diaria), label: "Resumen de meta diaria cumplida", limit: :infinity)
    IO.puts("\n")

    IO.puts("Reporte 4: Liquidación de confeccionistas")
    liquidaciones = ordenar_liquidaciones(lotes, confeccionistas, lineas)
    IO.puts("\n")

    IO.puts("Reporte 5: Líderes por día")
    mejor_desempeno = lideres_por_dia(lotes, confeccionistas)
    IO.inspect(mejor_desempeno, label: "Líderes por día", limit: :infinity)
    IO.puts("\n")

    IO.puts("Reporte 6: Confeccionista con mejor calidad")
    mejor_calidad(lotes, confeccionistas, lineas)
    IO.puts("\n")

    IO.puts("Reporte 7: Resumen financiero semanal")
    resumen_financiero_semanal(lotes, confeccionistas, lineas)
    IO.puts("\n")

    IO.puts("Reporte 8: Confeccionistas que trabajaron en todas las líneas de producción")
    en_todas_las_lineas(lotes, confeccionistas, lineas)

  end

end
