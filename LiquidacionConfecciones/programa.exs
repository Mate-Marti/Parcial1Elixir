# Integrantes: (escriban aquí los nombres del grupo)

defmodule Programa do
  @moduledoc """
  Punto de entrada. Concentra TODOS los efectos secundarios (IO.gets / IO.puts).
  La validación, la liquidación y los cálculos de reportes son puros y viven en
  Validacion, Liquidacion y Reportes.
  """

  @doc "Ejecuta el flujo completo: datos, lote adicional, reportes y comprobante.
  recibe los datos de confeccionistas, líneas y lotes desde Datos, y luego llama a las funciones de Validacion,
  Liquidacion y Reportes para procesar los datos y generar los reportes correspondientes."
  def main do
  confeccionistas = Datos.confeccionistas()
    lineas = Datos.lineas()
    lotes = Datos.lotes()

    # 1. Lote adicional (antes de los reportes)
    # Se permite un lote adicional ingresado por el usuario, que se agrega a la lista de lotes sin validar.
    #io.puts("Lotes iniciales: #{length(lotes)}")
    {lotes_totales, mensaje} = incorporar_lote_adicional(lotes)
    IO.puts(mensaje)

    # 2. Validación
    # Se separan los lotes en válidos y rechazados, y se cuentan los motivos de rechazo.
    {validos, rechazados} = separar_lotes(lotes_totales, confeccionistas, lineas)

    # 3. Liquidación y reportes
    # Se calcula la liquidación de cada confeccionista a partir de los lotes válidos, y se generan los reportes correspondientes.
    liquidaciones = Liquidacion.liquidar(validos, confeccionistas)
    imprimir_reportes(validos, rechazados, liquidaciones, confeccionistas, lineas)

    # 4. Comprobante individual
    # Se solicita al usuario el código de un confeccionista y se imprime su comprobante individual, si existe.
    imprimir_comprobante(validos, confeccionistas)
  end
  # Entrada de datos
#recibe un mensaje y devuelve el texto ingresado por el usuario, eliminando los espacios en blanco al inicio y al final
#case IO.gets(mensaje) obtiene la entrada del usuario, y String.trim(texto) elimina los espacios en blanco al inicio y al final del texto
#is_binary(texto) verifica si el valor de texto es una cadena de caracteres, y devuelve el texto ingresado si es así; de lo contrario,
#devuelve una cadena vacía
  defp leer_linea(mensaje) do
    case IO.gets(mensaje) do
      texto when is_binary(texto) -> String.trim(texto)
      _ -> ""
    end
  end

  # Devuelve {lista_de_lotes_con_el_adicional_si_aplica, mensaje_para_el_usuario}.
  # El lote adicional se agrega SIN validar aquí: la validación ocurre después,
  # junto con los demás, y si es rechazado aparece en R1.
  #util.parsear_lote(texto) analiza el texto ingresado por el usuario y devuelve un resultado {:ok, lote}
  #si el texto es válido y se puede convertir en un lote, o {:error, motivo} si el texto es inválido
    #lotes ++ [lote] agrega el lote adicional a la lista de lotes existentes, creando una nueva lista que contiene todos los lotes,
     incluyendo el adicional
  defp incorporar_lote_adicional(lotes) do
    texto =
      leer_linea(
        "Ingrese un lote adicional (confeccionista;linea;dia;prendas;defectos)\n" <>
          "o Enter para omitir: "
      )
    if texto == "" do
      {lotes, "Lote adicional omitido."}
    else
      case Util.parsear_lote(texto) do
        {:ok, lote} -> {lotes ++ [lote], "Lote adicional recibido; se validará con los demás."}
        {:error, motivo} -> {lotes, "Lote adicional rechazado: #{inspect(motivo)}"}
      end
    end
  end

  # Separa en {validos, rechazados}; rechazados es [{lote, motivo}]
  #enum.map(lotes, &Validacion.validar_lote(&1, confeccionistas, lineas)) aplica la función de validación a cada lote de la lista,
  #generando una lista de resultados {:ok, lote} o {:error, motivo}
  #for {:ok, lote} <- resultados, do: lote filtra los resultados válidos, extrayendo solo los lotes que pasaron la validación
  #enum.zip(lotes, resultados) combina la lista de lotes con la lista de resultados, creando una lista de tuplas {lote, resultado}
  defp separar_lotes(lotes, confeccionistas, lineas) do
    resultados = Enum.map(lotes, &Validacion.validar_lote(&1, confeccionistas, lineas))

    validos = for {:ok, lote} <- resultados, do: lote

    rechazados =
      for {lote, {:error, motivo}} <- Enum.zip(lotes, resultados), do: {lote, motivo}

    {validos, rechazados}
  end
  # Reportes (solo imprimen lo que calculan los módulos puros)
  defp titulo(texto), do: IO.puts("\n=== #{texto} ===")
# Solicita un código de confeccionista y muestra su comprobante individual.
  defp imprimir_reportes(validos, rechazados, liquidaciones, confeccionistas, lineas) do
    reporte_1(rechazados)
    reporte_2(validos, lineas)
    reporte_3(validos)
    reporte_4(liquidaciones)
    reporte_5(validos, confeccionistas)
    reporte_6(validos, confeccionistas)
    reporte_7(liquidaciones)
    reporte_8(validos, confeccionistas, lineas)
    rankings(liquidaciones)
  end
#enum.each(liquidaciones, fn l -> IO.puts("  #{l.nombre} (#{l.codigo}): #{Util.formatear_dinero(l.neto)}") end)
#itera sobre cada liquidación en la lista de liquidaciones, y para cada liquidación l,
#imprime el nombre del confeccionista, su código y el valor neto formateado como dinero
#io.puts("\nRanking de confeccionistas por neto:") imprime un encabezado para el ranking de confeccionistas por neto
  defp reporte_1(rechazados) do
    titulo("R1. Lotes rechazados")

    Enum.each(rechazados, fn {lote, motivo} ->
      IO.puts("#{inspect(lote)} -> #{motivo}")
    end)

    IO.puts("\nRechazos por motivo:")

    rechazados
    |> Reportes.contar_rechazos()
    |> Enum.each(fn {motivo, cantidad} -> IO.puts("  #{motivo}: #{cantidad}") end)
  end
#reporte_2/2 genera un reporte de productividad por línea, mostrando la cantidad de prendas
#y la productividad (prendas por puesto) para cada línea.
#utiliza Reportes.productividad_lineas/2 para calcular la productividad por línea a partir
#de los lotes válidos y las líneas, y luego imprime los resultados en la consola.
#enum.each/2 itera sobre cada línea en la lista de productividad por línea, y para cada línea l,
#imprime el nombre de la línea, la cantidad de prendas y la productividad formateada como dinero
  defp reporte_2(validos, lineas) do
    titulo("R2. Productividad por línea (prendas por puesto)")

    # [%{id:, nombre:, prendas:, productividad:}] ya ordenado de mayor a menor
    validos
    |> Reportes.productividad_lineas(lineas)
    |> Enum.each(fn l ->
      IO.puts(
        "#{l.nombre}: #{l.prendas} prendas, #{Util.formatear_dinero(l.productividad)} prendas/puesto"
      )
    end)
  end
#enum.each/2 itera sobre cada par {dia, prendas} en la lista de producción diaria, y para cada par,
#imprime el día, la cantidad de prendas y el estado de la meta (alcanzada o no alcanzada) en la consola.
#resumen = Reportes.resumen_meta(produccion) calcula un resumen de la meta alcanzada, que indica si la meta
# se alcanzó todos los días y si se alcanzó al menos un día.
  defp reporte_3(validos) do
    titulo("R3. Producción diaria vs meta")

    # %{1 => n, ..., 6 => n}
    produccion = Reportes.produccion_diaria(validos)

    Enum.each(produccion, fn {dia, prendas} ->
      estado = if Reportes.meta_cumplida?(prendas), do: "meta alcanzada", else: "meta NO alcanzada"
      IO.puts("Día #{dia}: #{prendas} prendas (#{estado})")
    end)

    resumen = Reportes.resumen_meta(produccion)
    IO.puts("Meta alcanzada todos los días: #{si_no(resumen.todos)}")
    IO.puts("Meta alcanzada al menos un día: #{si_no(resumen.alguno)}")
  end
#rankings(liquidaciones) genera tres rankings de confeccionistas según diferentes criterios:
#ranking(liquidaciones, []) genera un ranking por neto (de mayor a menor)
#ranking(liquidaciones, campo: :prendas, limite: 3) genera un ranking por prendas (de mayor a menor) con un límite de 3
#ranking(liquidaciones, orden: :asc, campo: :bruto) genera un ranking por bruto (de menor a mayor)
  defp reporte_4(liquidaciones) do
    titulo("R4. Liquidación de confeccionistas")

    liquidaciones
    |> Reportes.ranking(campo: :neto)
    |> Enum.with_index(1)
    |> Enum.each(fn {l, i} ->
      IO.puts(
        "#{i}. #{l.nombre} (#{l.codigo}) | prendas: #{l.prendas}" <>
          " | lotes: #{Util.formatear_dinero(l.bruto)}" <>
          " | bonif: #{Util.formatear_dinero(l.bonificaciones)}" <>
          " | alquiler: #{Util.formatear_dinero(l.alquiler)}" <>
          " | neto: #{Util.formatear_dinero(l.neto)}"
      )
    end)
  end
# genera un ranking de confeccionistas según el criterio especificado
#recibe la lista de liquidaciones y un campo opcional para ordenar (por defecto, neto)
#utiliza Reportes.ranking/2 para calcular el ranking de confeccionistas según el campo especificado, y
#luego imprime los resultados en la consola.
#reportes.lideres_por_dia/2 calcula los líderes de producción por día a partir de los lotes válidos y los confeccionistas,
#y devuelve una lista de mapas con el día, la cantidad de prendas y los nombres de los líderes de producción para ese día
#enum.each/2 itera sobre cada líder de producción en la lista de líderes, y para cada líder,
#imprime el día, la cantidad de prendas y los nombres de los líderes de producción en la consola.
  defp reporte_5(validos, confeccionistas) do
    titulo("R5. Líder de producción por día")

    # [%{dia:, prendas:, lideres: [nombres]}]  (lideres == [] si no hubo lotes)
    lideres = Reportes.lideres_por_dia(validos, confeccionistas)

    Enum.each(lideres, fn
      %{dia: dia, lideres: []} ->
        IO.puts("Día #{dia}: sin lotes válidos")

      %{dia: dia, prendas: prendas, lideres: nombres} ->
        IO.puts("Día #{dia}: #{Enum.join(nombres, ", ")} (#{prendas} prendas)")
    end)

    case Reportes.mas_dias_en_primer_lugar(lideres) do
      {_dias, []} ->
        IO.puts("Nadie ocupó el primer lugar.")

      {dias, nombres} ->
        IO.puts("Más días en primer lugar (#{dias}): #{Enum.join(nombres, ", ")}")
    end
  end

  defp reporte_6(validos, confeccionistas) do
    titulo("R6. Mejor calidad (defectos ponderados por prendas)")

    case Reportes.mejor_calidad(validos, confeccionistas) do
      {:ok, %{nombre: nombre, porcentaje: porcentaje}} ->
        IO.puts("#{nombre}: #{Util.formatear_dinero(porcentaje)} % de defectos ponderado")

      {:error, :sin_datos} ->
        IO.puts("Nadie tiene al menos 3 lotes válidos.")
    end
  end
#utilizamos Util.formatear_dinero/1 para formatear el porcentaje de defectos ponderado como dinero, con dos decimales y
# sin notación científica

  defp reporte_7(liquidaciones) do
    titulo("R7. Total pagado y costo por prenda")

    resumen = Reportes.costo_total(liquidaciones)
    IO.puts("Total a pagar: #{Util.formatear_dinero(resumen.total)}")

    case resumen.promedio do
      {:ok, promedio} -> IO.puts("Costo promedio por prenda: #{Util.formatear_dinero(promedio)}")
      {:error, :sin_prendas} -> IO.puts("No hay prendas válidas: el promedio no puede calcularse.")
    end
  end
#case para observar si los confeccionistas trabajaron en todas las líneas, y si es así, imprime sus nombres; de lo contrario,
#indica que no hubo confeccionistas que trabajaran en todas las líneas.
#una lista vacia si no hubo confeccionistas que trabajaran en todas las líneas, o una lista de nombres de confeccionistas que sí lo hicieron
  defp reporte_8(validos, confeccionistas, lineas) do
    titulo("R8. Confeccionistas que trabajaron en todas las líneas")

    case Reportes.en_todas_las_lineas(validos, confeccionistas, lineas) do
      [] -> IO.puts("Ningún confeccionista trabajó en todas las líneas.")
      nombres -> Enum.each(nombres, &IO.puts("  #{&1}"))
    end
  end

  # C.1: las tres llamadas obligatorias a ranking/2
  defp rankings(liquidaciones) do
    titulo("C.1 Rankings")

    IO.puts("\nranking(liquidaciones, [])")
    imprimir_ranking(Reportes.ranking(liquidaciones, []), :neto)

    IO.puts("\nranking(liquidaciones, campo: :prendas, limite: 3)")
    imprimir_ranking(Reportes.ranking(liquidaciones, campo: :prendas, limite: 3), :prendas)

    IO.puts("\nranking(liquidaciones, orden: :asc, campo: :bruto)")
    imprimir_ranking(Reportes.ranking(liquidaciones, orden: :asc, campo: :bruto), :bruto)
  end

  # Las prendas son enteros; los demás campos son dinero (dos decimales, sin notación científica).
  defp imprimir_ranking(ranking, campo) do
    Enum.each(ranking, fn l -> IO.puts("  #{l.nombre}: #{formatear_campo(l, campo)}") end)
  end

  defp formatear_campo(liquidacion, :prendas), do: liquidacion.prendas
  defp formatear_campo(liquidacion, campo), do: Util.formatear_dinero(Map.fetch!(liquidacion, campo))

  defp si_no(true), do: "sí"
  defp si_no(false), do: "no"
  # Comprobante individual


  defp imprimir_comprobante(validos, confeccionistas) do
    codigo = leer_linea("\nIngrese el código del confeccionista para su comprobante: ")

    case Liquidacion.comprobante(codigo, validos, confeccionistas) do
      {:ok, c} ->
        titulo("Comprobante de #{c.nombre} (#{c.codigo})")

        Enum.each(c.dias, fn d ->
          IO.puts(
            "Día #{d.dia}: #{d.prendas} prendas | lotes: #{Util.formatear_dinero(d.valor_lotes)}" <>
              " | bonificación: #{Util.formatear_dinero(d.bonificacion)}"
          )
        end)

        IO.puts("Suma de lotes: #{Util.formatear_dinero(c.suma_lotes)}")
        IO.puts("Suma de bonificaciones: #{Util.formatear_dinero(c.suma_bonificaciones)}")
        IO.puts("Descuento por alquiler: #{Util.formatear_dinero(c.alquiler)}")
        IO.puts("Neto: #{Util.formatear_dinero(c.neto)}")

      {:error, :confeccionista_desconocido} ->
        IO.puts("El código \"#{codigo}\" no existe.")
    end
  end
end

Programa.main()
