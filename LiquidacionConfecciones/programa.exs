defmodule Programa do

  def main do
    confeccionistas = Datos.confeccionistas()
    lineas = Datos.lineas()
    lotes = Datos.lotes()

    menu(confeccionistas, lineas, lotes)
  end

  def menu(confeccionistas, lineas, lotes) do
    IO.puts("\nMenú de opciones:")
    IO.puts("1. Mostrar confeccionistas")
    IO.puts("2. Mostrar líneas")
    IO.puts("3. Mostrar lotes")
    IO.puts("4. Validar lotes")
    IO.puts("5. Salir")

    opcion = IO.gets("Seleccione una opción: ")
    |> String.trim()
    # utilizamos case para tomar decisiones a través del menú
    case opcion do
      "1" ->
        IO.inspect(confeccionistas, label: "Confeccionistas existentes")
        menu(confeccionistas, lineas, lotes)
      "2" ->
        IO.inspect(lineas, label: "Líneas existentes")
        menu(confeccionistas, lineas, lotes)
      "3" ->
        IO.inspect(lotes, label: "Lotes existentes")
        menu(confeccionistas, lineas, lotes)
      "4" ->
        resultados =
          Enum.map(lotes, fn lote ->
            Validaciones.validar_lote(lote, confeccionistas, lineas)
          end)
        IO.inspect(resultados, label: "Resultados")
        menu(confeccionistas, lineas, lotes)
      "5" ->
        IO.puts("Saliendo del programa...")
      _ ->
        IO.puts("Opción inválida. Intente nuevamente.")
        menu(confeccionistas, lineas, lotes)
    end
  end
end

Programa.main()
